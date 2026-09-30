# Run 27 — Nine sample projects: open, click around, preview, save and publish

## Why
Earlier runs fixed Preview (Runs 15–16) but never re-tested Save or Publish after the null-player fix (Run 09's failures). This run opened nine real-world sample projects, clicked through their panels and dialogs, previewed them and published them, to find whatever still breaks.

## How
- The nine sample projects were `all-questions`, `QuizTime`, `Tabs`, `DragDrop-Packt`, `Ch4-Ex5`, `Numbers-French-SL2` (a Storyline 2 file), `Periodic-Elements-SL360`, `improved-fullscreen` (a JavaScript trigger) and `sequential-previous`.
- Each was opened through the Dock launcher with the project as an argument. Clicks went through `tools/uiauto/sl` (Wine `SendInput`), so they reach Storyline's windows the way a real mouse does.
- DragDrop-Packt, Ch4-Ex5, Periodic-Elements and improved-fullscreen were published with Run 28's patch 0025 installed, so their times are a little shorter than this branch alone gives.
- Published output was loaded in headless Chromium (Playwright) from `file://`. The script read each slide's accessible text, took screenshots, and clicked or dragged where the course expects it.

## Problems found and fixed
1. **Opening a project from the launcher did nothing.** Storyline opens only its first command-line argument as a file (`MainFormBase` reads `GetCommandLineArgs()[1]`), and the launcher put the CEF switches first. A Mac path also means nothing to Windows code. `tools/launcher/storyline-launcher.sh` now puts arguments before the switches and maps an existing absolute Mac path to Wine's `Z:` drive.
2. **Radio buttons and checkboxes were missing from the slide canvas, and Slide Layers thumbnails were blank.** Storyline records these shapes as EMF+ metafiles and plays them back. Wine's gdiplus had four problems there:
   - Most drawing records never grew the metafile's automatic frame, so the frame stayed empty and playback clipped everything away.
   - A pen's alignment (inset or centred) was recorded as a float instead of an integer, and never applied on playback.
   - The `ResetClip` record was not played back.
   - Patch 0021 (Run 26) made `GdipSetWorldTransform` and `GdipResetWorldTransform` relative to the current container, but metafile playback sets the transform in device space. Playback now assigns it directly.

   Patch `0023-gdiplus-fix-metafile-frame-bounds-pen-alignment-ResetClip-and-playback-space.patch` fixes all four.
3. **Every circle outline had a notch.** Flattening a closed ellipse leaves its last point a few ulps away from its first. Wine's `remove_repeated_points` compared points with `memcmp`, so the near-duplicate survived. Widening then turned a near-zero segment into a notch. Patch `0024-gdiplus-tolerate-rounding-when-removing-repeated-path-points.patch` compares with a relative tolerance of 1e-5.

## Results

| Project | Opened | Clicked through | Preview | Published |
|---|---|---|---|---|
| all-questions | yes | question slides (radio buttons and checkboxes), Slide Layers | — | LMS (SCORM 2004); Save round-trip (valid zip, identical XML entries) |
| QuizTime | yes | Story View, layers, triggers | START, tile, answer ("CORRECT +100"), player gear panel | Web, 40 s; plays in Chromium |
| Tabs | yes | layers, States panel, Edit States, Done | — | — |
| DragDrop-Packt | yes | layers, Form View, Drag & Drop Options | two drags scored 1/5 then 2/5 | Web, 23 s; a drag in Chromium scores 1/5 |
| Ch4-Ex5 | upgrade prompt, then yes | slider, trigger conditions | slider shows the matching layer | Video (modern player upgrade accepted), 45 s; 1440×1080 H.264, 10.1 s, frames correct |
| Numbers-French-SL2 | "Missing Fonts" (Adobe Fan Heiti Std B), upgrade | slides | — | Web, Classic player, about 60 s untraced; slides 1–4 navigate in Chromium |
| Periodic-Elements-SL360 | "Missing Fonts" (Ebrima) | branching Story View, layers, Reporting and Tracking dialog | — | LMS (SCORM 1.2), 84 s; valid manifest, menu navigation works in Chromium |
| improved-fullscreen | "Missing Fonts" | JavaScript Editor (highlighted code) | slide shows | Web, 9 s; the trigger's JavaScript ran in Chromium (body and frame styles set) |
| sequential-previous | yes | — | menu jump to slide 5, then Previous goes to slide 4 | — |

- No crash, hang or unhandled exception in any session. Storyline's log shows only known noise: LaunchDarkly "not yet initialized" warnings, one filepicker.io HTTP 404 per session, one RPC disconnect at shutdown, and one "Slide thumbnail is null" warning per project open.
- The "Missing Fonts" dialogs are legitimate: those fonts ship with Windows or Adobe apps, not with Wine.
- Wine's gdiplus tests, built by hand (tests are disabled in this build), give identical results with 0023 and 0024 and without them: `metafile` 1984 tests with the same 6 failures, `graphics` 5619 tests with the same 2 failures, `graphicspath` 1168 tests with 0 failures.
- Build: 0023 and 0024 pass `git apply --check` after 0013, 0014 and 0021, and both `gdiplus.dll`s build.

## Known issues, not fixed
- **No antialiasing.** Wine's gdiplus ignores the smoothing mode ("Smoothing mode is not used anywhere" in its source), so curves and diagonal edges in Storyline's UI and slide canvas are jagged. Fixing that is a rasterizer project of its own.
- **Finder double-click** on a `.story` file does not open it: the bash launcher gets no file argument from an Apple Event (`odoc`).

## Not verified
- Review 360 and Word publishing, and Reach 360 upload.
- Typing into Storyline. The Mac screen was locked for most of this run, and Wine keyboard injection does not reach a locked session.
- Clicks inside WPF dialogs (Reporting and Tracking Options, JavaScript Editor) did nothing with injected input while the screen was locked. The dialogs drew correctly and closed normally on `WM_CLOSE`. Whether real mouse clicks work in them was not re-checked in this run.
