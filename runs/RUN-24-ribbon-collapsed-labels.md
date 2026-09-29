# Run 24 — Crowded ribbon: collapsed buttons still drew their labels

## Why
With a slide open, the Home tab's Clipboard, Slide and AI Assistant groups overlapped. "Format Painter", "Apply Layout", "Focus Order" and "Duplicate" were drawn on top of New Slide and Insert Text.

## What Storyline does
Storyline's ribbon is WinForms, not WPF. When a tab is wider than the ribbon, Storyline collapses the small side-by-side buttons of its least important groups to icons only. At the 1440-px window on a 1440×900 display the slide-view Home tab needs about 1580 px, the ribbon has 1434, and Clipboard and Slide collapse. That is by design.

A collapsed button measures its text as zero width but still lays out a text rectangle, which ends up 3 px wide in the negative direction (right edge left of the left edge). Storyline's ribbon renderer then draws the label with Win32 `DrawText` using `DT_NOCLIP | DT_SINGLELINE`.

A startup hook that dumped the ribbon's layout from inside Storyline confirmed it: the six overlapping buttons had text bounds of width −3, and the buttons that were not collapsed (Quiz, Question, Summary) measured normally.

## Root cause
Wine's `DrawTextExW` draws the whole string whenever `DT_NOCLIP` is set, whatever the rectangle's shape. So every collapsed label was drawn at full length from the button's right edge.

Windows presumably draws nothing into that rectangle, or collapsed groups would overlap there too. This is inferred, not tested on Windows. Screenshots from Windows tutorials (a 2026 capture at 1920 px and a 2022 capture at 1280 px) show the same tab drawn cleanly, but in both the tab fits and nothing collapses.

Ruled out:
- **`TextRenderer` clipping.** A test program showed Wine clipping `TextRenderer.DrawText` and `DrawTextW` correctly for zero-width and inverted rectangles when `DT_NOCLIP` is not set, with and without a clip region and transform on the `Graphics`.
- **Missing Segoe UI.** Storyline asks for Segoe UI at 11 px, which the prefix lacks, so labels fall back to Microsoft Sans Serif. Mapping Segoe UI to Microsoft's open-source, metric-compatible Selawik changed a set of seven ribbon labels from 459 px to 454 px, which is not enough to stop the collapse. The Windows 2026 capture at 100% scaling needs about 1520 px for the same tab, so it would collapse in a 1440-px window too.

## Fix: patch 0019
`tools/wine-patches/0019-user32-draw-nothing-for-inverted-DrawText-rectangles.patch` skips the drawing step in `DrawTextExW` when the rectangle's right edge is left of its left edge. Measuring is unchanged: the return value and `DT_CALCRECT` results are the same, and zero-width and normal rectangles still draw. `build-ntdll.sh` applies it (and stops if it neither applies nor is already applied) and installs 64- and 32-bit `user32.dll` into the mirror.

Patching Wine rather than Storyline keeps to the rule of no patched Articulate binaries.

## Results
- Test program, same device context and font: an inverted rectangle with `DT_NOCLIP` draws nothing (it drew the full string before); zero-width and normal rectangles draw as before; all return 13 (the line height), and `DT_CALCRECT` still returns the full text width.
- Storyline, new project, slide open, Home tab, 1440×817 window: Cut, Copy, Format Painter, Apply Layout, Focus Order and Duplicate show as icons, and nothing overlaps New Slide or the AI Assistant group.
- Insert tab, same window: its collapsed buttons (Quiz, Question and Summary; the Text group's side buttons; the Interactive Objects extras) show as icons with no overlap. The Design tab fits and does not collapse.
- Startup: the first launch with the patch, right after force-quitting Storyline, stayed on the splash for over 2.5 minutes and was killed. Relaunches then reached the start screen in 66 s without the patch and 57 s with it.

## Not yet verified
- Windows behaviour for `DrawText` with `DT_NOCLIP` and an inverted rectangle has not been checked on a Windows machine.
- Tabs other than Home, Insert and Design, and dialogs, have not been checked for side effects.
- The slow first launch has not been reproduced; it may have been left over from the force-quit.
