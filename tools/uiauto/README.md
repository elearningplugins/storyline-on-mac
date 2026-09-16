# UI automation helpers

- `slauto.c` → `x86_64-w64-mingw32-gcc -O1 -o slauto.exe slauto.c -luser32`; run inside the prefix with the patched Wine:
  `list` · `wait <title> [s]` · `focus <title>` · `keys "<text>{ENTER}{CTRL+n}{WAIT:500}"` · `click x y` · `clickw <title> x y`.
  `focus`/`clickw` attach to the target's input thread so `SetForegroundWindow` is honoured across processes.
- `activate.swift` → `swiftc -O -o activate activate.swift`; `activate <pid>` brings the Wine app to the front on macOS.
  Do **not** use `open -a` / AppleScript `activate` on the launcher bundles: the bundle script `exec`s Wine, so LaunchServices
  starts a *second* Storyline instance instead of activating the running one.
- Verification needs `screencapture`, which only shows windows when the calling app has macOS Screen Recording permission.
