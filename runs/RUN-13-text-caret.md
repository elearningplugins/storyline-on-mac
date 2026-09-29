# Run 13 — Missing text caret

## Symptom
Typing into a slide text box or the Notes pane worked, but no blinking caret was ever drawn. The ribbon's font-size box (a stock Win32 edit control) showed its caret normally.

## Ruled out
- Win32 caret path: Storyline's text editor does not use `CreateCaret`/`ShowCaret`; it paints its own caret.
- Focus alone: `tools/probes/focusprobe.c` (`GetGUIThreadInfo`) showed the Notes pane's editor window holding keyboard focus while still showing no caret.
- AI writer popup, window activation, caret blink time, WPF hardware rendering: no change.

## Root cause
Storyline paints its caret through Direct2D on a GDI-compatible DC render target: it fills a small bitmap with opaque white and draws it with `ID2D1DeviceContext::DrawImage(..., D2D1_COMPOSITE_MODE_MASK_INVERT)`, which inverts the pixels underneath. Wine 11.16's `d2d_device_context_DrawImage` only implements `SOURCE_OVER`; any other composite mode logs `FIXME("Unhandled composite mode ...")` and falls through to a normal draw, so the caret came out as white on a white background. `ID2D1DCRenderTarget` forwards `QueryInterface(ID2D1DeviceContext)` to its inner device context, so the call lands on that code path.

## Fix
Patch 0008 (`tools/wine-patches/0008-d2d1-implement-mask-invert-composite-mode.patch`, d2d1 PE): when a bitmap target is set, a second D3D11 blend state is created with `SrcBlend = INV_DEST_COLOR`, `DestBlend = INV_SRC_ALPHA` and destination alpha preserved (`Oc = Sc·(1−Dc) + Dc·(1−Sa)`, `Oa = Da`). `DrawImage` swaps it in for `MASK_INVERT` draws of bitmaps and restores the normal blend state afterwards. For an opaque white source this is an exact invert; for coloured sources it scales by source colour rather than source alpha, which is enough for masks.

## Result
Caret blinks in slide text boxes and in the Notes pane. It takes noticeably long to appear after clicking into a box; not yet investigated (earlier probes showed Win32 focus landing on the slide stage before the editor).
