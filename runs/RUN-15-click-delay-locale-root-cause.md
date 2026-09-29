# Run 15 — Click delay: a Wine locale gap made Storyline reload its player on every click

## Why
After Run 13 the caret was visible, but clicking into a text box still took about 3 s to show it (about 5 s when typing between clicks), and New Project took 30–38 s to load. Run 14's logging showed the time was spent on Storyline's UI thread, not in drawing.

## Hands-off sessions
`tools/perf/auto-caret.sh [label] [clicks] [VAR=value …]` runs a whole session without anyone at the keyboard. It starts `perf-session.sh`, opens a new project with Alt+N, adds two text boxes, clicks into them alternately, closes without saving and prints the summary. `NO_TYPING=1` only clicks, and `SAMPLE_AT="5 7"` takes a macOS `sample` around those clicks. Coordinates assume the maximised 1440×817 window on a 1440×900 display.

It is built on `tools/uiauto/`:
- `slauto.exe` (runs inside the prefix) gained `dclick`, `drag`, `waittext`/`clicktext <label>` (finds a visible control by its exact text in any window), `tree` and `close`.
- Storyline lays a transparent layered WPF window (`HwndWrapper[Storyline;Main;…]`) over its main window. macOS clicks pass through its clear pixels, but Wine hit-tests injected input by rectangle, so every injected click landed on the overlay. `slauto` sets `WS_EX_TRANSPARENT` on it before clicking.
- `sl` builds and runs `slauto.exe` and brings Storyline to the front first, because injected input only lands while it is the frontmost Mac app.
- `shot.sh` captures Storyline's window through a helper that runs in Terminal (`shotd.sh`), which holds the Screen Recording permission. Storyline stops repainting while it is behind another app, so the script brings it forward for the capture and hands focus back afterwards.

## Ruled out first
- **Runtime settings.** Server GC and `TieredPGO=0` changed project load, but not the click delay, across interleaved runs. Runs taken while `pmset -g therm` reported a CPU speed limit were discarded.
- **Wine's low-level mouse hook timeout.** Injected `SendInput` calls returned in about 0.1 ms, so no hook was stalling input.
- **File lookups.** Patch 0011 (`WINE_PERF_LOG` per-second file lookup totals by thread and folder, reported by `perf-summary.py`) showed about 4 s of UI-thread file lookups over 19 clicks, mostly in Storyline's player `strings_*.xml` folder. That was a symptom: something was re-reading those files on each click.

## Root cause
A .NET EventPipe trace (sample profiler plus exception events, converted with `dotnet-trace`) showed each click spending its time in Storyline refreshing the slide side panel. That refresh asks the project for its default player, and building the player sorts about 90 player string tables by their language's display name.

Three of those languages (`tet`, `sm`, `nya`) have no locale data in Wine. .NET checks a culture name by calling `GetLocaleInfoEx(name, LOCALE_SNAME)`. Windows 10 answers for any well-formed tag it has no data for, treating it as a custom unspecified locale (LCID `0x1000`). Wine returned 0, so .NET threw `CultureNotFoundException`, the sort failed with `InvalidOperationException`, Storyline's player loader caught it and returned no player, and nothing was cached. Every click then probed and parsed all the string files again. The same null player caused the `NullReferenceException`s from the accessibility checkers in Storyline's log.

It is not an ICU data problem: the failure is identical in .NET's NLS mode and with Microsoft's full ICU 72 in place of Wine's `icu.dll`.

## Fix: patch 0012
`tools/wine-patches/0012-kernelbase-answer-LOCALE_SNAME-for-unknown-well-formed-locale-names.patch` makes `GetLocaleInfoEx` return the name itself for `LOCALE_SNAME` when the name is a well-formed tag (2–3 letter language, then 2–8 character alphanumeric subtags) that Wine has no data for, as Windows 10 does. Every other query for an unknown name still fails. `build-ntdll.sh` applies it (and stops if it neither applies nor is already applied) and installs 64- and 32-bit `kernelbase.dll` into the mirror.

A small .NET test program in the prefix now resolves `tet`, `sm`, `nya` and other well-formed unknown tags to LCID 4096, as on Windows. Patching Wine rather than Storyline keeps to the rule of no patched Articulate binaries.

## Results
Same hands-off script, two text boxes, 12 clicks, default runtime settings, no thermal limit.

| | Before (3 runs) | After |
|---|---|---|
| Click → caret, median, clicks only | 3.38 / 3.01 / 3.49 s | 226 ms (p95 710 ms) |
| Click → caret, median, typing between clicks | 4.93 s | 252 ms (p95 749 ms) |
| New Project load | 37.8 / 28.9 / 36.1 s | 3.4 s / 3.2 s |
| Storyline CPU, mean (100% = one core) | 101–105% | 57% / 53% |
| UI-thread file lookups over the session | ~4 s | ~0.1 s |
| Error lines in Storyline's log | 25–65 | 0 |

The file-lookup cache that was planned next is not needed: the remaining UI-thread file time is about 1.3 s over a 3-minute session.

## Not yet verified
- Preview, Save, the Player dialog and Publish failed in Run 09 with null-player `NullReferenceException`s. This is likely the same missing player, but they have not been re-tested.
- The slowest clicks still take 0.7–1.1 s; that is a separate, smaller cost.
- The fix is a candidate for upstream Wine.
