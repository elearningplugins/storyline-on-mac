# Run 17 — GDI+ drawing: white scene-card corners and nubs on pill buttons

## Symptom
In Story View, each scene card has a white quarter circle at every corner, as if the card's background were cut off. The straight edges of the card's shadow look right.

## Cause
Story View is a WinForms control painted with GDI+ (Wine's builtin `gdiplus.dll`; `vmmap` shows Storyline loading it). The card shadow is a slate-blue fade (alpha 26 → 10 → 0 over 17 px). The edges are `LinearGradientBrush` rectangles, and each corner fills a 17×17 square with a `PathGradientBrush` built on a circle around the card corner. Both brushes get their colours only from `InterpolationColors`, a preset blend.

Wine's `gdiplus` applies preset blends to linear gradients but not to path gradients: `brush_fill_pixels` prints `FIXME("path gradient preset blend not implemented")` and paints with the brush's centre and surround colours. Those were never set, so they are GDI+'s defaults, opaque white. Only pixels inside the circle are painted, hence white quarter circles.

## Fix: patch 0013
`tools/wine-patches/0013-gdiplus-implement-path-gradient-preset-blend.patch`: when a path gradient has a preset blend, each pixel's colour comes from the blend at its position between the path boundary (0) and the centre point (1), the same positions `GdipSetPathGradientPresetBlend` documents. Without a preset blend, the existing centre/surround interpolation is unchanged. `build-ntdll.sh` applies it and installs 64- and 32-bit `gdiplus.dll`.

## Verified
- `tools/probes/pgradprobe.c` paints the same corner on Story View's grey (`b8bec8`). Stock Wine: `ffffffff` everywhere inside the quarter circle. Patched: `b8bec8` at the edge, darkening smoothly to `afb5c1` at the card corner, which is the grey blended with (87, 95, 125) at alpha 26.
- Wine's own `gdiplus` conformance tests, built standalone against Wine's headers and run on stock and patched builds: `brush` 1178 tests, 0 failures, both; `graphics` 5619 tests, 244 todo, 1 failure, both. The failure is the same pre-existing one (`graphics.c:7443`).

## Pill buttons: patch 0014
After a restart the scene cards looked right. The rounded Save / Don't Save / Cancel buttons (Articulate's `MetroButton`) still had small nubs hanging under the bottom edge near both ends.

The button fills a pill path (two 180° arcs plus `CloseAllFigures`) without antialiasing, then strokes the same path with a 1 px pen and antialiasing on. Wine's `GdipClosePathFigures` only marked a figure closed when another figure started after it, so a path's last figure (here the only one) stayed open. The stroke then left out the straight bottom edge between the two arcs, and the arcs' ends showed as nubs. `GdipClosePathFigure` (singular) already closed the last figure; Windows closes all of them.

`tools/wine-patches/0014-gdiplus-close-the-last-figure-in-GdipClosePathFigures.patch` also marks the last point closed. `tools/probes/closeprobe.c` prints the path types. Stock Wine: the last point is `03` (no close flag), and the widened outline is open. Patched: `83`. A pixel dump of the fill plus antialiased outline showed row 35 painted only at x 15–17 and 78–80 before the patch, and continuously from x 15 to 80 after.

Wine's `graphicspath` tests (1168, 30 todo, 0 failures) pass the same on stock and patched builds, as do `brush` and `graphics` (same counts as above).

## Not verified
- The buttons in Storyline after a restart (patch 0014 was built while Storyline was running).
- Path gradient blend factors (`GdipSetPathGradientBlend`), focus scales, gamma and transforms are still unimplemented in Wine; Storyline's other path gradient (`ImagingHelper.DrawDropShadow` with focus scales, used by the form view background) may still look off.
