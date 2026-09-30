# Run 26 — Triggers panel: missing lines and missing "–" marks

## Why
In slide view, the Triggers panel's Player Triggers looked wrong. Under each trigger group ("Next Button / Swipe Next") the first line ("When the user clicks or swipes next") was missing, the row was mostly blank, and "Jump to slide next slide" sat at the bottom of the row, cut off, without the "–" that Windows draws in front of it.

## What Storyline does
The trigger list is WinForms drawing with GDI+ and `TextRenderer`, not WPF:
- `TriggersList.OnPaint` opens a `BeginContainer` for each list item and translates the `Graphics` down to the item's top.
- `TriggerItemView.PaintTrigger` opens a second, nested `BeginContainer` before painting its lines.
- Each text block is drawn with `TextRenderer.DrawText(..., PreserveGraphicsTranslateTransform)`, and the "–" mark with the same flag at a point rather than in a rectangle.

With that flag, WinForms reads the `Graphics`' current transform and adds the offset each open container saved when it began (`Graphics.GetContextInfo`), then applies the sum to the HDC. That only adds up if the transform inside a container is relative to the container, which is what .NET's code assumes.

Ruled out: the fonts. The list asks for "Segoe UI Symbol" at 12 px, which the prefix lacks; Wine falls back to Microsoft Sans Serif, and a test program measured the trigger text at 193×15 px with normal metrics.

## Root causes
1. **gdiplus**: Wine's `GdipBeginContainer2` saves the state but leaves the world transform as it is, so inside a container `GdipGetWorldTransform` still returns the outer translation. WinForms then adds the container's saved offset on top, and every line painted inside the nested container lands one item-offset too low, where the row's clip cuts it off.
2. **win32u**: for text drawn at a point, WinForms passes a rectangle that extends to `Int32.MaxValue`. After the viewport offset, Wine's `GDI_ROUND` converts a value just past `INT_MAX` with a plain cast, which on x86-64 gives `INT_MIN`. The clip rectangle turns upside down and the "–" is clipped away.

## Fix: patches 0021 and 0022
- `tools/wine-patches/0021-gdiplus-make-the-world-transform-relative-to-BeginContainer.patch`: each `BeginContainer` records the full transform at entry as the container's base. `GdipGetWorldTransform`, `GdipSetWorldTransform`, `GdipResetWorldTransform` and the translate, scale, rotate and multiply calls work on the transform relative to that base, so the transform inside a new container starts as identity. Drawing still uses the full transform, so rendering code is unchanged. `GdipSaveGraphics` blocks do not start a new base.
- `tools/wine-patches/0022-win32u-saturate-GDI_ROUND-instead-of-wrapping.patch`: `GDI_ROUND` saturates at `INT_MAX` and `INT_MIN` instead of relying on an out-of-range cast, which is undefined behaviour in C. In-range values are unchanged.

`build-ntdll.sh` applies 0021 with the other gdiplus patches and 0022 with the win32u patches. Patching Wine rather than Storyline keeps to the rule of no patched Articulate binaries.

## Results
- Test program, `Graphics` translated by 40 px inside two nested containers: the transform reads `0,0` inside the inner container with 0021. With 0022 the "–" drawn at a point appears next to the "Jump" drawn in a rectangle; without it only "Jump" appears.
- Storyline, slide view, with Group checked (grouped layout, as in the Windows reference screenshot): each Player Trigger shows "When the user clicks or swipes next" and "– Jump to slide next slide" on even spacing, matching the Windows layout. With Group unchecked (Storyline's default "classic" layout), both lines also show, action first, as that layout lists them.
- Build: both patches pass `git apply --check` in the build script's order (0021 after 0013 and 0014; 0022 on pristine `ntgdi_private.h`). `make` builds both `gdiplus.dll`s and `win32u.so`.

## Not yet verified
- Windows' transform inside `BeginContainer` is inferred from .NET's `GetContextInfo` and the Windows screenshot, not measured on Windows. Wine's own gdiplus tests don't cover it.
- Windows also starts each container with an unbounded clip; Wine still keeps the outer clip. Text drawn with `PreserveGraphicsClipping` inside containers may still differ.
- Other GDI+ users in the prefix (the Desktop App, other Storyline panels) were not checked for changes; 32-bit `gdiplus.dll` was built but not exercised.
