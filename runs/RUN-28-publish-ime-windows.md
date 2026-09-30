# Run 28 — Publish: a Cocoa window for every text box

## Why
Publishing Numbers-French-SL2 (32 slides) to Web took about a minute in Run 27, and most of it was the first phase in Storyline's log ("content"). A sampling trace of that phase showed Storyline's publish thread spending much of its time creating and destroying windows rather than in its own code.

## What happens
- Storyline exports each text box through a WinForms `TextPane` control that owns a window handle. WinForms parks controls without a visible parent under its message-only `ParkingWindow`, and destroys the parking window again when its last child leaves (`CheckDestroy`).
- Wine gives each thread a hidden "Default IME" top-level window when the thread's first window appears (`register_imm_window` in `win32u/window.c`), and destroys it when the thread's last window goes away. Wine already skips message-only windows themselves, but not their children.
- On macOS every top-level window gets a Cocoa window, created and destroyed on the main thread. A test program measured about 4 ms to create one and 12 ms to destroy it.
- So each text box Storyline exported on its publish thread created and destroyed a Cocoa window.

Windows does not do this: ReactOS' `IntWantImeWindow`, which follows Windows' behaviour, gives no IME window to descendants of message-only windows.

## Fix: patch 0025
`tools/wine-patches/0025-win32u-no-default-IME-window-for-descendants-of-message-only-windows.patch` adds one condition to `NtUserCreateWindowEx`. A child window whose top-level ancestor is a message-only window gets no default IME window. The check uses the same `NtUserGetAncestor(NtUserGetAncestor(h, GA_ROOT), GA_PARENT) == get_hwnd_message_parent()` idiom Wine already uses elsewhere. Top-level windows, including ones owned by a message-only window, still get one.

`build-ntdll.sh` applies it after 0022 with the other win32u patches.

## Results
- **Test program** (`imebench`, a thread that repeatedly creates a message-only window with a child and grandchild, then destroys them):

  | | Before | With 0025 |
  |---|---:|---:|
  | Create-and-destroy cycle | 23.4 ms | 2.1 ms |
  | Default IME window for the child and grandchild | yes | none |
  | Default IME window for a top-level window, its child, and a window owned by the message-only window | yes | yes (unchanged) |

  Creating a child under a message-only parent while the thread keeps another top-level window alive is unchanged (0.24 ms create, 0.13 ms destroy), because the IME window already exists.
- **Storyline, Numbers-French-SL2 published to Web** (Classic player), cold launch each time, alternating builds:

  | Order | Build | Content phase | Whole publish (Storyline's log) |
  |---:|---|---:|---:|
  | 1 | 0025 | 38 s | 64 s |
  | 2 | before | 49 s | 66 s |
  | 3 | 0025 | 37 s | 55 s |
  | 4 | before | 49 s | 67 s |
  | 5 | 0025 | 37 s | 63 s |
  | 6 | before | 50 s | 77 s |

  The content phase drops by 12 s every time. The whole publish varies more (the last phases, image compression and file writing, swing by several seconds), with means of 70 s before and 61 s with 0025. The prefix ran at its configured `RetinaMode=y` and 192 DPI, which is slower than the Run 27 publishes of the same project.

- The output of the last 0025 run loads in headless Chromium and shows the title slide's text.
- Run 27's DragDrop-Packt, Ch4-Ex5, Periodic-Elements and improved-fullscreen publishes ran with 0025 installed and produced working output.
- Build: 0025 passes `git apply --check` in the build script's order (before 0009, which also edits `window.c`), and `win32u.so` builds.

## Not verified
- Typing with an input method (Japanese, Chinese) in a text box that WinForms had parked and then re-parented. Windows gives such windows the IME window of their new top-level ancestor, and Wine's per-thread IME window should behave the same once the thread has any top-level window, but it was not tested with a real input method.
- Wine's `imm32` tests were not run (they do not build in this tree without extra work).
