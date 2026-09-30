# Run 31 — "New" and "Beta" badges are empty blue boxes

## Why
On Windows, the right panel's AI Assistant tab has a small "New" badge. On the Mac it was a blank blue box. This build of Storyline labels it "Beta", but it is the same badge.

![Before: empty blue badge next to AI Assistant](img/run31-badge-before.png)

## Cause
- Storyline paints every feature badge (the right panel tabs, ribbon buttons, ribbon menu items, callouts) with `FeatureBadge.PaintAtFontSize`. It fills the rounded box with GDI+, then draws the text with its own `gdi32.DrawText(Graphics, text, font, Point, color, flags)` helper.
- That helper builds the text rectangle as `new Rectangle(location, new Size(int.MaxValue, int.MaxValue))`. Its right and bottom edges overflow, so Win32 `DrawTextW` gets a rectangle like `20,10 - -2147483629,-2147483639`, with flags 0 (no `DT_NOCLIP`).
- Wine's `DrawTextExW` passes the rectangle to `ExtTextOutW` with `ETO_CLIPPED`, which clips all of the text. Windows draws the text, so it evidently does not clip to a rectangle like this. How Windows arrives at that was not checked; its GDI only supports coordinates up to ±2^27, so these edges are outside what it can represent anyway.
- Patch 0019, which draws nothing into inverted rectangles, is not the cause: a test program drew nothing for this rectangle with stock MacPorts Wine too.

## Fix: patch 0028
`tools/wine-patches/0028-user32-treat-DrawText-rectangle-edges-that-wrapped-around-as-unbounded.patch` adds a check at the top of `DrawTextExW` in `dlls/user32/text.c`. When the right edge is more than 2^27 left of the left edge, or the bottom more than 2^27 above the top, that edge wrapped around and is treated as unbounded (`MAXLONG`). The change applies to a local copy of the rectangle, so the caller's rectangle is not modified, and `DT_CALCRECT` is left alone. A rectangle inverted by a normal amount, such as the −3 px collapsed ribbon labels from patch 0019, is unaffected.

`build-ntdll.sh` applies it after 0019 in the user32 step.

## Results
Test program (`DrawTextW` of "New" into a 32-bit DIB, 13 px Tahoma), lit pixels:

| Rectangle and flags | Stock Wine | 0019 | 0019 + 0028 |
|---|---:|---:|---:|
| Normal, flags 0 | 173 | 173 | 173 |
| Point + `int.MaxValue` (Storyline's badge), flags 0 | 0 | 0 | 173 |
| Right and bottom `INT_MIN`, flags 0 | 0 | 0 | 173 |
| Width −3, `DT_NOCLIP \| DT_SINGLELINE` (collapsed ribbon label) | 173 | 0 | 0 |
| Width −3, `DT_SINGLELINE` | 0 | 0 | 0 |

The return value is 16 (the line height) in every case.

Storyline, `Tabs.story` copy, slide 1.1 open, same session setup, only `user32.dll` swapped:

![After: the badge reads Beta](img/run31-badge-after.png)

The same screenshots show the Home tab's collapsed Clipboard and Slide buttons still drawn as icons with no overlapping labels (patch 0019's case).

## Not yet verified
- The ribbon's own "New" badges (for example on Insert Avatar in some builds) use the same `PaintAtFontSize` path but were not shown in this build, so they were not checked separately.
- Windows was not tested directly; the Windows behaviour comes from the user's Windows screenshot of the same badge.
