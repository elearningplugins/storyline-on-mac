# Storyline 360 on macOS (Intel) via Wine — research log

Can the current Articulate 360 / Storyline 360 Windows apps run on an Intel Mac through upstream Wine — no VM, no Boot Camp, no CrossOver, no remote Windows, no licensing/auth bypass?

**Where it stands:** the Articulate 360 Desktop App signs in, and Storyline 360 installs, launches, opens, previews, saves and publishes projects on a patched Wine 11.16 (Run 27 went through nine sample projects). It is slower than on Windows and draws without antialiasing. This is a research log, not something to install for day-to-day work.

**Scope:** Intel Macs only. Apple Silicon (Rosetta 2 / Game Porting Toolkit) was not tested and is not supported here. You need your own Articulate 360 subscription and installers; none are included.

Full method and constraints: [docs/research-plan.md](docs/research-plan.md). Every experiment is recorded under [runs/](runs/) with sanitized logs under [logs/](logs/). Licensed binaries, Wine prefixes, and snapshots are kept outside this repo; [SHA256SUMS](SHA256SUMS) pins the exact inputs.

## Environment

| | |
|---|---|
| Host | 2019 MacBook Pro 15,4 (Core i5, Iris Plus 645), macOS 15.7.9 |
| Wine | MacPorts `wine-devel` 11.16 (`+ffmpeg +gstreamer`, binary archive), Wine Mono 11.3.0, Gecko 2.47.4 |
| MacPorts | 2.12.6 Sequoia pkg, SHA-256 + Developer ID/notarization verified |
| Input | `articulate-360.exe` (Burn 3.11.2, bundle 1.125.37980.0), SHA-256 `bc725a70…c88e9` |
| Winetricks | release 20260125, tag commit `57063f0b…` |

## Status board

| Step | Result | Run |
|---|---|---|
| Xcode CLT | Was broken (missing libc++ headers); clean reinstall fixed it | logs/macports/clt-reinstall.txt |
| MacPorts + Wine 11.16 install | OK — binary archives; only `gd2`/`graphviz` built from source | logs/macports/ |
| Burn bootstrapper UI (WPF, under Wine Mono) | **Renders correctly** | 01 |
| VC++ 2015–2022 x86 / x64 | **OK** (0x0) | 01 |
| Core MSI, stock prefix | **FAIL** 0x80070643 — `RegisterScheduledTaskAction` hits Wine stub `ITaskSettings::get_IdleSettings` (E_NOTIMPL) | 01 |
| Core MSI with `DisableNonAdminInstalls=true` | **OK** (0x0) — Articulate's documented setting skips the task | 02 |
| `Articulate 360 Desktop App.exe`, Wine Mono | **FAIL** — TypeLoadException: `EventLogInvalidDataException` missing from Mono's System.Core | 03 |
| Original EXE, real .NET 4.8 prefix | **degrades** — Burn can't host managed BA (0x8007000e), installs nothing | 04a |
| Core MSI direct, real .NET 4.8 | **FAIL** 1603 — DTF custom action can't create CLR AppDomain (0x8007000E) | 04b |
| Core MSI admin layout (`msiexec /a`) + registry import | **OK** | 04c |
| `Articulate 360 Desktop App.exe`, real .NET 4.8 | **RUNS** — service spawned, RPC OK, HTTPS OK | 04d |
| Sign-in / entitlement / catalog (Gate 1) | **PASS** via OIDC loopback fallback (custom-scheme handler timed out on macOS) | 04d |
| Restart persistence, HiDPI, Dock launcher | **OK** (`~/Applications/Articulate 360.app`) | 04e |
| Storyline install from the app | **BLOCKED** — app forces a Desktop App self-update first; update runs Burn → CLR hosting fails | 04e |
| Root cause of CLR hosting failure | **FOUND** — Wine gives 32-bit processes `0x7fff0000-0x7fffffff` (wow64 `default_zero_bits`) | 05 |
| Patched `ntdll.so` research build | **WORKS** — core MSI custom actions run; original EXE installs end-to-end under real .NET 4.8 | 06 |
| Storyline install (official bundle, direct) | **INSTALLED** — all 5 packages 0x0 incl. .NET Desktop Runtime 10 | 07 |
| Install via Desktop App → Installer Service | **FAIL** — "Directory has unexpected ACL" (Wine security-descriptor round-trip) | 07 |
| Storyline launch + start page | **RUNS** (CEF GPU process fails → software fallback, slow first paint) | 08 |
| New Project → text layout | **FIXED** by patch 0002 — authoring window renders, 0 exceptions | 08 |
| Preview | **WORKS** — the null player came from the locale gap fixed by patch 0012 (Run 15); the blank preview pane was CEF drawing from a separate GPU process, fixed by `--in-process-gpu` in the launcher | 16 |
| Save / Player dialog / Publish | **WORKS** — Save round-trips; Publish to Web, LMS (SCORM 1.2 and 2004) and Video produce output that plays in Chromium. Run 09's failures were the null player fixed by patch 0012 | 09, 27 |
| Graphics feature level | **FIXED** by patch 0003 — Direct3D feature level 9_3 → 11_1 on MoltenVK | 10 |
| Text box editing | FL fixed (0003), D2D shaders fixed (0004); the "freeze" is the AI writer popup's 30 Hz layered-window loop — CPU 182% → 63% with 0005 (0006 was not actually deployed until Run 14) | 11 |
| Incident | **T2 ANS2 (SSD controller) panic** during heavy `+file` tracing — tracing rules added | 09 |
| New Project load | 20.9 s → **13.7 s** warm (RNG + colour-space patches); rest is .NET JIT of IL-only assemblies | 12 |
| CEF GPU (start-page panel, browser views) | **degraded** — Wine d3d11 has no WARP device; hardware ANGLE also fails; software fallback after retries. Views drew nothing because winemac can't show a child window drawn by another process; `--in-process-gpu` keeps CEF's compositor in Storyline | 09, 16 |
| Desktop App drawing on the Vulkan renderer | **FIXED** by WPF software rendering (was clipped labels and stray lines; OpenGL renderer drew a blank window; patch 0005 ruled out; 0006 was not deployed then) | — |
| Text cursor in text boxes and Notes | **FIXED** by patch 0008 — Wine's d2d1 drew `MASK_INVERT` images as plain source-over, so the white caret was invisible; caret still takes a while to appear | 13 |
| Performance instrumentation | `tools/perf/perf-session.sh` + patch 0009 (`WINE_PERF_LOG=1`): caret/typing latency, D2D paint cost, layered-window load, CPU per process | 14 |
| CEF start-up | `--enable-features=NetworkServiceInProcess2` in the launcher runs Chromium's network service as a thread instead of another `Storyline.exe` (.NET boot); `Cef.Initialize` 2.3 s → **1.9 s** mean of 3 traced cold launches | 20 |
| Click delay and New Project load | **FIXED** by patch 0012 — Wine didn't answer `GetLocaleInfoEx(LOCALE_SNAME)` for unknown well-formed locale names, so Storyline's player failed to load and was rebuilt on every click; click → caret 3.3 s → **0.23 s**, load 30–38 s → **3.4 s** | 15 |
| Story View scene-card shadows | **FIXED** by patch 0013 — Wine's gdiplus ignored preset blends on path gradient brushes, so the rounded shadow corners painted solid white | 17 |
| Pill buttons (Save / Don't Save / Cancel…) | **FIXED** by patch 0014 — Wine's `GdipClosePathFigures` never closed a path's last figure, so the antialiased outline skipped the bottom edge and left nubs at both ends | 17 |
| Start screen right panel (Articulate's web content) | **FIXED** by patch 0015 — the panel is an IE `WebBrowser` (Wine's mshtml + Gecko), kept hidden until `ProgressChanged` reports a finished load; Wine never fired that event, so the panel stayed blank | 18 |
| Busy cursor (e.g. after New Project) | **FIXED** by patch 0016 — winemac had no Mac equivalent for the Windows wait and app-starting cursors, so it drew the Windows hourglass; it now shows AppKit's busy cursor | 19 |
| Image decoding (icons, WIC) | **FIXED** by patch 0017 — windowscodecs re-read the codec lists from the registry on every decode (~97 wineserver round trips per image); small icons 1.9 ms → **0.26 ms** each | 21 |
| Desktop Service wait at launch | **IMPROVED** — the Dock launcher starts the service before Storyline asks for it; cold launch waits 12–13 s instead of 18–21 s for the service. About 4 s left is the service retrying a missing Review backups file (inside Articulate; not fixable here). Warm relaunches (service still running) wait 0.4 s | 22 |
| Storyline opened from the Desktop App | **FIXED** by patch 0018 — the Desktop App started `Storyline.exe` with none of the launcher's CEF switches (so no in-process GPU, which Preview needs, Run 16); `WINE_APPEND_ARGS` (set by both Dock launchers from `tools/launcher/storyline-args.sh`) makes Wine's `CreateProcess` add them | 23 |
| Crowded Home ribbon in slide view | **FIXED** by patch 0019 — when the ribbon is too narrow, Storyline collapses small buttons to icons, but Wine's `DrawText` still drew their labels into a negative-width rectangle, over the next group | 24 |
| Blurry text on Retina displays | **IMPROVED** by patch 0020 and Retina mode at 192 DPI — Storyline is DPI-unaware, so every pixel is doubled; Wine's default halftone doubling was the blurriest option, and the launchers now pick xBR (`WINE_SCALE_FILTER=xbr`), which keeps edges crisp and the 96-DPI layout unchanged. Truly sharp slide text needs Storyline to render at 2×, which breaks its fixed-pixel layout. Patch 0029 fixes a start-up race that sometimes turned Retina mode off for Storyline, which then opened at 720×407 with double-size web content | 25 |
| Triggers panel spacing | **FIXED** by patches 0021 and 0022 — Wine's gdiplus kept the outer transform visible inside `BeginContainer`, so WinForms counted each trigger's offset twice and pushed lines out of their rows; and an unbounded WinForms text rectangle wrapped negative after a viewport offset, so the "–" before each action vanished | 26 |
| Radio buttons and checkboxes on the slide canvas, Slide Layers thumbnails | **FIXED** by patch 0023 — Wine's gdiplus left most metafile records out of the frame bounds, dropped pen alignment and `ResetClip` on playback, and (after 0021) played back in container space instead of device space | 27 |
| Notch in circle outlines | **FIXED** by patch 0024 — a closed ellipse's last point sat a few ulps off its first, and widening turned the gap into a notch | 27 |
| Opening a project from the Dock launcher | **FIXED** in the launcher — Storyline opens only its first argument, so the project goes before the CEF switches, with a Mac path mapped to `Z:`. Finder double-click still does not pass the file | 27 |
| Publish speed | **IMPROVED** by patch 0025 — Wine gave every window under WinForms' message-only parking window a hidden IME window, and on macOS each one creates and destroys a Cocoa window; Numbers-French-SL2 to Web: content phase 49–50 s → **37–38 s**, whole publish 66–77 s → **55–64 s** (three cold runs each) | 28 |
| No-break spaces (issue #20) | **FIXED** by patch 0026 (opt-in, set by the launchers) — Storyline breaks a line at any character DirectWrite calls white space, and DirectWrite, on Windows too, calls U+00A0, U+2007 and U+202F white space; `WINE_DWRITE_NBSP_NOT_WHITESPACE=1` stops that, so words joined by a no-break space wrap together (verified on the authoring canvas and in published output) | 29 |
| Japanese and Chinese candidate list position | **IMPROVED** by patch 0027 — Storyline draws its own text caret and never tells the IME where it is, so Wine gave macOS a position of 0,0 and the candidate list opened at the top left of the screen; it now opens at the bottom left of the slide canvas, where Windows puts the default IME window in the same case (not next to the typed text, because Storyline does not report its caret) | 30 |
| "New"/"Beta" feature badges (e.g. next to AI Assistant) | **FIXED** by patch 0028 — Storyline draws the badge text with `DrawText` into a rectangle of the point plus `int.MaxValue`, which overflows to a huge negative edge; Wine clipped the text to that inverted rectangle and drew an empty blue box, and now treats an edge that wrapped around as unbounded | 31 |
| Antialiasing | **MISSING** — Wine's gdiplus ignores the smoothing mode, so curves and diagonal edges are jagged | 27 |


## Current setup (what actually runs)

- **Patched Wine**: `~/StorylineLab/wine-patched/` is a symlink mirror of `/opt/local/lib/wine` with only the patched modules
  replaced — `ntdll.so` (0001, 0007, 0011), `dwrite.dll` (0002, 0026), `wined3d.dll` (0003), `d2d1.dll` (0004, 0008, 0009), `winemac.so` (0005, 0010, 0016, 0029),
  `win32u.so` (0006, 0009, 0020, 0022, 0025, plus MacPorts' Vulkan portability patch), `kernelbase.dll` (0012, 0018), `gdiplus.dll` (0013, 0014, 0021, 0023, 0024), `ieframe.dll` (0015), `windowscodecs.dll` (0017), `user32.dll` (0019, 0028) and `imm32.dll` (0027) — plus a copy of the loader and a `share` symlink. Patches are in `tools/wine-patches/`; all of them are
  built by `tools/wine-build/build-ntdll.sh`. `/opt/local` is never modified. PE modules the prefix keeps its own copy of
  (e.g. `system32/dwrite.dll`) are replaced with the patched build too.
- **Prefix**: `~/StorylineLab/prefixes/wine-dotnet48-noadmintask` — real .NET Framework 4.8 (winetricks), Windows 10 mode,
  `DisableNonAdminInstalls=true`, Articulate 360 core laid out via `msiexec /a` + registry import, Storyline installed by the
  official bundle, .NET Desktop Runtime 10 x64 from that bundle. Mac driver: `LeftCommandIsCtrl`/`RightCommandIsCtrl=y`;
  `RetinaMode=y` with `LogPixels=192` since Run 25 (it was `n` because WPF dialogs went blank in Run 04e; the Desktop App's main window draws correctly with it on now, its secondary dialogs are not re-tested); `Direct3D\renderer=vulkan` since Run 10; WPF hardware
  acceleration off (`HKCU\Software\Microsoft\Avalon.Graphics\DisableHWAcceleration=1`) because the Desktop App drew clipped
  labels and stray lines through wined3d on Vulkan and nothing at all on OpenGL.
- **Launchers**: `~/Applications/Articulate 360.app` and `~/Applications/Storyline 360.app` (tools/launcher/) run the genuine
  EXEs on the patched Wine; `~/Applications/Articulate360Bridge.app` handles `articulate://` sign-in callbacks. Both set
  `WINE_MAC_APP_NAMES` so the menu bar and Dock say "Articulate 360" and "Storyline 360" instead of "wine" (patch 0010 in
  `winemac.so`, which names each process after its Windows exe). Both also source `storyline-args.sh`, whose
  `WINE_APPEND_ARGS` makes the patched `kernelbase.dll` (patch 0018) add Storyline's CEF switches however it is started, and
  `WINE_DWRITE_NBSP_NOT_WHITESPACE=1`, which turns on patch 0026.
  Both set `WINE_SCALE_FILTER=xbr` so the patched `win32u.so` (patch 0020) doubles Storyline's windows with xBR on Retina displays.

## What worked

- **Articulate 360 Desktop App signs in and shows the full catalog under Wine 11.16 + real .NET Framework 4.8** (Run 04). Desktop Service is spawned by the app; no Windows service or scheduled task needed.
- `msiexec /a` (administrative install) lays the core package out without running any custom action; the only registry the real installer writes is three small keys, imported from a prefix where it did complete.
- Articulate's own OIDC loopback fallback completes sign-in when the `articulate://` custom scheme has no macOS handler. A transport-only handler app is provided in `tools/macos-url-bridge/` for the primary path.

- Upstream Wine 11.16 from MacPorts binary archives — no source build, no Gatekeeper workarounds.
- Running the original `articulate-360.exe` unmodified. The WPF managed bootstrapper paints and runs its detect/plan/apply phases under Wine Mono.
- Pre-setting `HKLM\Software\Articulate\Common\Settings\DisableNonAdminInstalls = "true"` (REG_SZ) in the prefix before install. This is Articulate's own enterprise deployment switch; it makes the installer skip Task Scheduler registration, which is the only part of the core MSI Wine can't handle.

## What didn't

- Native CLR hosting under real .NET 4.8 on stock Wine: both WiX Burn's `mbahost` and DTF `SFXCA` fail with 0x8007000E creating an AppDomain, while managed EXEs run normally. Root cause is Wine's wow64 address range for 32-bit processes (Run 05); fixed by patch 0001 (Run 06).

- Xcode CLT as found on the machine: `clang++` could not find `<initializer_list>`. Any C++ source build fails until `rm -rf /Library/Developer/CommandLineTools && xcode-select --install`.
- MacPorts `port -s` (force source build) is not needed and would be slow on this hardware; skip it unless patching Wine.
- Core MSI in a stock prefix: Wine's `taskschd` stubs `get_IdleSettings`, and Articulate's custom action (using the managed TaskScheduler wrapper) throws on it. A Wine patch returning a stub `IIdleSettings` would also fix this (not attempted; registry route was cheaper).
- Wine Mono as a stand-in for .NET Framework 4.8: good enough for the installer UI, not for the Desktop App (missing `System.Diagnostics.Eventing.Reader` types).

## Reproduce

```bash
# prerequisites (privileged): MacPorts 2.12.6, then
sudo port install wine-devel cabextract

# 1. prefix: real .NET 4.8, Windows 10, DisableNonAdminInstalls, and every prefix setting listed under "Current setup"
tools/build-prefix-dotnet48.sh wine-dotnet48-noadmintask

# 2. Articulate 360 core laid out without custom actions (needs ~/StorylineLab/inputs/burn-payloads from your own installer)
tools/install-core-admin.sh wine-dotnet48-noadmintask

# 3. patched Wine mirror (all nine patches), then its PE modules copied into the prefix's system32
tools/wine-build/build-ntdll.sh wine-dotnet48-noadmintask

# 4. Dock launchers and the articulate:// bridge in ~/Applications
tools/launcher/install-launchers.sh

# 5. Storyline: sign in with the Articulate 360 app, then run the official bundle it downloads under the patched Wine (Run 07)
WINEPREFIX=~/StorylineLab/prefixes/wine-dotnet48-noadmintask ~/StorylineLab/wine-patched/bin/wine ~/StorylineLab/inputs/storyline-360-x64-bundle.exe

# any step with focused Wine logging
tools/run-wine-logged.sh wine-dotnet48-noadmintask burn ~/StorylineLab/inputs/articulate-360.exe
```

`tools/install-core-admin.sh` takes `burn-payloads/` from the Burn package cache of an earlier install attempt (Run 04b); with the patched Wine, running the original `articulate-360.exe` also installs the core end to end (Run 06).

`tools/run-wine-logged.sh` writes a header (macOS build, Wine version, prefix, Windows build number, input hash, exit code) to each log so every run is self-describing.

To time a Storyline session, quit Storyline and run `tools/perf/perf-session.sh <label> [VAR=value ...]`. It launches Storyline with `WINE_PERF_LOG=1`, samples CPU once a second, and writes `summary.txt` to `~/StorylineLab/perf/<time>-<label>/` when you quit. Add `--sample-clicks N` after the label to take a stack sample of Storyline after each of your first N clicks once a project has loaded. `tools/perf/perf-mark.sh "text"` adds a timestamped note during a session. See Run 14. `tools/perf/auto-caret.sh <label> [clicks]` runs a whole caret session hands-off (new project, two text boxes, repeated clicks); see Run 15.

## Rules kept

No Gatekeeper/SIP changes, no quarantine stripping, no `--no-sandbox`, no TLS/licensing/code-signing bypass, no patched Articulate binaries. The only change to Articulate's behavior is a registry value its own deployment guide documents.

## License

Scripts and documentation are MIT ([LICENSE](LICENSE)). The Wine patches in `tools/wine-patches/` are LGPL-2.1-or-later, the same terms as Wine. `tools/winetricks-20260125` is an unmodified, pinned copy of [winetricks](https://github.com/Winetricks/winetricks) kept for reference, under its own LGPL-2.1-or-later license.

## Disclaimer

Not affiliated with, endorsed by, or supported by Articulate Global, LLC. Articulate 360 and Storyline 360 are trademarks of Articulate; the launcher icons in `tools/launcher/` are drawn from scratch by the `makeicon*.swift` scripts to identify the apps in the Dock and are not Articulate artwork. Running Articulate software this way is unsupported by Articulate and requires your own licensed copy.
