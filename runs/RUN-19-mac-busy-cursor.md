# Run 19 — Busy cursor: the Windows hourglass instead of a Mac one

## Symptom
After clicking New Project (and anywhere else Storyline is busy), the pointer turns into the Windows hourglass.

## Cause
WinForms' `Cursors.WaitCursor` is the standard Windows wait cursor (`IDC_WAIT`, `USER32.dll` resource 32514). winemac swaps standard Windows cursors for native ones through a table in `dlls/winemac.drv/mouse.c` (arrow, I-beam, resize, hand, and so on). The table has no entry for the wait cursor (`OCR_WAIT`) or the app-starting cursor (`OCR_APPSTARTING`, 32650). So winemac converts Windows' bitmap into an `NSCursor`, and you get the hourglass.

AppKit has no public busy cursor. The spinning beach ball is drawn by the window server when an app stops responding, and apps can't set it. The only built-in one is `+[NSCursor busyButClickableCursor]`, which is private: the arrow with a small spinning disc that Mac apps show while working. It exists on macOS 15.7 (checked with the Objective-C runtime).

## Fix: patch 0016
`tools/wine-patches/0016-winemac-show-the-AppKit-busy-cursor-for-the-wait-cursors.patch`:
- Maps `OCR_WAIT` and `OCR_APPSTARTING` to `busyButClickableCursor`.
- Because that method is private, `copy_system_cursor_name` asks the Cocoa side first (`macdrv_cursor_name_available`, which uses `respondsToSelector:`). If a future macOS removes the method, winemac draws the Windows cursor as before instead of sending an unknown selector to `NSCursor`, which would crash.

`build-ntdll.sh` applies it with the other winemac patches.

## Verified
- `tools/probes/waitcursorprobe.c` holds `IDC_WAIT` (or `IDC_APPSTARTING`) over its window, run with `WINEDEBUG=trace+cursor`.
  - Stock winemac: `setting cursor with cursor_name (null) cursor_frames 0x…`, meaning the Windows bitmap.
  - Patched, wait cursor: `L"USER32.dll,32514" -> "busyButClickableCursor"`, then `setting cursor with cursor_name "busyButClickableCursor" cursor_frames 0x0`.
  - Patched, app-starting cursor: the same, with `USER32.dll,32650`.
- The patch applies to the pre-patch sources and gives byte-identical files to those built. It reverse-applies, and `winemac.so` builds with no new warnings.

## Not verified
- Storyline itself: it had an unsaved project open, so it wasn't restarted on the new `winemac.so`. That Storyline's busy pointer is `IDC_WAIT` rather than a cursor of its own is inferred from WinForms `Cursors.WaitCursor`, not traced.
- Whether the disc spins. Screen captures here exclude the pointer, and the trace can't show animation. `NSCursor.image` gives one frame.
