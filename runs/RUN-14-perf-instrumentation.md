# Run 14 — Performance instrumentation

## Why
Once the caret became visible (Run 13), it still took a long time to appear. Several other slow spots were known only by rough measurement. This run adds logging so that every performance question is answered from the same session data.

## What is logged
Patch 0009 (`tools/wine-patches/0009-perf-log-instrumentation.patch`) adds `perf <seconds> <pid> <tid> <module> <event> key=value…` lines on stderr when `WINE_PERF_LOG=1`. It is silent otherwise. The Storyline launcher appends stderr to `~/StorylineLab/logs/launcher/storyline.log`.

| Event | Module | Content | Volume |
|---|---|---|---|
| `sync` | win32u | performance-counter time paired with Unix epoch, to align with `ps` and Storyline's log | once per process |
| `input mouse_down/mouse_up/key_down` | win32u | hardware input as it enters the queue (no key identity) | per click / key |
| `focus` | win32u | new and previous focus window, with class names | per focus change |
| `dcrt_frame` | d2d1 | per `ID2D1DCRenderTarget` frame: size, `BeginDraw` upload (window DC → surface), `EndDraw` total, present (surface → window DC), whether the caret was drawn | per paint |
| `ulw_window` | win32u | per-second `UpdateLayeredWindow` count, time spent, copy vs blend path, window size | 1 line/s while active |

`WINE_ULW_NOCOPY=1` turns off patch 0006's copy path so the two paths can be compared in otherwise identical sessions.

`tools/perf/perf-session.sh <label> [VAR=value …]` launches Storyline with the logging on. It samples CPU time and RSS of every Wine process once a second (classed as storyline, cef_gpu, cef_renderer, cef_other, wineserver, desktop_app, desktop_service, wine_other). When Storyline quits, it collects the perf lines and Storyline's own JSON logs for the session and runs `tools/perf/perf-summary.py`. The summary reports:
- click → focus → first frame → first caret frame, per click; key → next frame; caret blink interval
- D2D DC render target upload / EndDraw / present times per target size, and share of one core
- layered-window update rate, time and copy/blend split
- CPU mean / p95 / max and peak RSS per process class (plus `cpu-timeline.csv`)
- Storyline's project-load time (`AbandonProjectJobs` → `ProjectReadyForBackgroundProcessing`), log levels, CEF GPU lines
- notes added with `tools/perf/perf-mark.sh`
- with `--sample-clicks N`: after the project loads, a macOS `sample` plus `vmmap` of Storyline for 8 s after each of the next N clicks, with the busiest thread's time attributed to named Windows modules or anonymous (JIT) memory

Session data stays in `~/StorylineLab/perf/`. It includes Storyline's logs, which carry account IDs, so it is not committed.

## Found while building it
- **Patch 0006 was never active.** `NtUserUpdateLayeredWindow` is compiled into `win32u.so`, but `build-ntdll.sh` only copied `win32u.dll`. The mirror kept a symlink to MacPorts' stock `win32u.so`, so Run 11's 182% → 63% came from 0005 alone. The build now installs `win32u.so`.
- **MacPorts patches win32u.** Its `wine-devel` port applies one upstream fix, "win32u: Enable host Vulkan portability enumeration". A `win32u.so` built from the plain tarball fails `vkCreateInstance` with `VK_ERROR_INCOMPATIBLE_DRIVER` on MoltenVK, and every D2D target then fails with `DXGI_ERROR_UNSUPPORTED`. The patch is vendored in `tools/wine-patches/upstream/` and applied by the build.

## Smoke test (synthetic program, not Storyline)
Focus changes, a 200×100 DC render target and a 100×100 layered window at ~30 Hz all logged. A first DC frame took 50 ms (almost all in present), and later ones 1–2 ms. With `WINE_ULW_NOCOPY=1` every update took the blend path; without it every update took the copy path. With `WINE_PERF_LOG` unset, no lines were logged.

## Sessions to run
| Label | Extra env | What to do |
|---|---|---|
| `baseline` | — | open a project, click into a slide text box and the Notes pane several times, type a sentence in each, open and close the AI writer popup |
| `ulw-blend` | `WINE_ULW_NOCOPY=1` | same steps, to isolate patch 0006 |
| `ai-off` | — | same steps with Storyline's AI Assistant turned off, if its options allow it |
| `dotnet-tc` | one of `DOTNET_TieredCompilation=0`, `DOTNET_TC_QuickJitForLoops=0`, `DOTNET_OSR_HitLimit=0` | File → New and open a project, to see .NET JIT settings against Run 12's 13.7 s |
