# UI automation helpers

- `slauto.c` → `x86_64-w64-mingw32-gcc -O1 -o slauto.exe slauto.c -luser32`; run inside the prefix with the patched Wine:
  `list` · `wait <title> [s]` · `focus <title>` · `keys "<text>{ENTER}{CTRL+n}{WAIT:500}"` · `click x y` · `clickw <title> x y` ·
  `dclick x y` · `dclickw <title> x y` · `drag x1 y1 x2 y2` · `waittext|clicktext "<label>" [s]` · `tree <title>` · `close <title>`.
  `focus`/`clickw` attach to the target's input thread so `SetForegroundWindow` is honoured across processes. Clicks and drags first make
  Storyline's transparent layered overlay window input-transparent, since Wine hit-tests injected input by rectangle.
- `sl <slauto command …>` builds `slauto.exe` if needed, brings Storyline to the front for input commands (injected input only lands
  while it is the frontmost Mac app) and runs it in the prefix with `WINE_PERF_LOG=1`.
- `shot.sh <out.png> [pid]` captures Storyline's largest window through `shotd.sh`, a helper that runs in Terminal and so uses
  Terminal's Screen Recording permission; `winid.swift` finds the window. Storyline only repaints while frontmost, so the script
  brings it forward for the capture and hands focus back.
- `activate.swift` → `swiftc -O -o activate activate.swift`; `activate <pid>` brings the Wine app to the front on macOS.
  Do **not** use `open -a` / AppleScript `activate` on the launcher bundles: the bundle script `exec`s Wine, so LaunchServices
  starts a *second* Storyline instance instead of activating the running one.
- Verification needs `screencapture`, which only shows windows when the calling app has macOS Screen Recording permission.
