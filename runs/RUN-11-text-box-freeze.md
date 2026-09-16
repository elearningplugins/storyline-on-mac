# Run 11 — Text box "freeze": the AI writer popup's layered-window loop

With patches 0001–0004 active (Vulkan, FL 11_1): text render target created, Chromium GPU process healthy, Direct2D shaders
compile. Inserting a text box still "freezes" Storyline.

## Diagnosis chain
1. `sample`: not a hang — the Win32 UI thread sits in `GetMessage`; the wined3d CS thread submits GPU work and waits on fences;
   the Cocoa main thread spends ~44% in `CA::Transaction::commit`.
2. Direct2D trace: the text pane's paint completes; no D2D activity afterwards → not a D2D repaint storm.
3. Leaf-frame sample: `blend_rects_8888` (win32u), `memmove`, `vLookupTable_Planar8toPlanar16`,
   `provider_with_softmask_get_bytes…` (CoreGraphics) → per-frame layered-window composition + an alpha soft-mask conversion.
4. `+win` trace: `NtUserUpdateLayeredWindow` on hwnd 0x300ea — WPF `HwndWrapper[Storyline;Main;…]` titled **AiWriterWindow**,
   `WS_EX_LAYERED`, 800×515 — **2,700 updates in 88.4 s (30.5/s)** with an unchanged rectangle. Storyline's AI Assistant
   writer popup animates continuously through `UpdateLayeredWindow`. logs/patched-wine/aiwriter-layered-loop.txt
5. Wine side: `winemac.drv` `updateLayer` calls `[window invalidateShadow]` on **every draw** of a per-pixel-alpha window,
   so macOS recomputes the window shadow from the alpha channel 30×/s — that is the CoreGraphics soft-mask work.

## Fix (patch 0005, dlls/winemac.drv/cocoa_window.m)
Per-pixel-alpha (UpdateLayeredWindow) windows get `hasShadow = NO` (they draw their own shadows, like WPF popups do) and
`updateLayer` no longer invalidates the shadow for them; shape-changed windows keep the old behaviour. Built as `winemac.so`
(unix side only) into the mirror. Result: pending user test.

## Reported to Articulate (private gist)
https://gist.github.com/elearningplugins/5c2369a8b47aced28af54141bedfa9e1 — the 30 Hz repaint loop is platform-independent
and wasteful even on Windows; Storyline Options has no switch to disable the AI writer popup for this account.

## Measurements after patch 0005 (shadow)
Popup open, user idle: process CPU **182% → 63%**. Remaining cost (sample): `blend_rects_8888` (win32u AlphaBlend of the whole
frame over a cleared surface), memmove, and CoreGraphics colour conversion (`vUnpremultiplyData_RGBA8888`,
`vLookupTable_Planar8toPlanar16`, `vMatrixMultiply_Planar16S`) because the surface image is tagged sRGB on a P3 display.

## Patches 0005 (extended) and 0006
- winemac.drv surface.c: tag surface images with the device colour space instead of sRGB → no per-frame conversion.
- win32u window.c: `NtUserUpdateLayeredWindow` uses a 32bpp `BitBlt` instead of PatBlt+AlphaBlend when the blend is a plain
  per-pixel-alpha SRC_OVER at 255 (result is identical: source over black is the source). Built and installed; measuring next.
