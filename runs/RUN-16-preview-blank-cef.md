# Run 16 — Preview: blank pane from cross-process CEF drawing

## Symptom
With patch 0012 (Run 15), Preview no longer fails with a null player: Storyline publishes the preview in about 12.5 s with no errors or warnings in its log. The Preview ribbon, device buttons and status bar appear, but the content pane stays white, so Preview looks stuck.

## What the logs showed
- Storyline's log: `RibbonPreviewCommand`, then `PlayerWriter` writing content, frame, JavaScript, slides, Html5 and data.xml, then the publish background thread completing. Device switches were logged too.
- The CEF log: the preview page (`Preview/preview.html`) and the player scripts (`frame.desktop.min.js`, later `frame.mobile.min.js`) loaded and logged console messages. The player was running.
- Window tree: the pane is windowed CEF: `CefBrowserWindow` → `Chrome_WidgetWin_1` → `Chrome_RenderWidgetHostHWND`, children of Storyline's main window.

## Cause
Chromium draws those child windows from its separate GPU process (`Storyline.exe --type=gpu-process`). Wine on macOS can't show that:
- Direct3D/Vulkan presentation needs a Metal swapchain on the window; `macdrv_client_surface_acquire_metal_swapchain` (`dlls/winemac.drv/window.c`) returns failure with `FIXME("Cross-process child window Metal swapchains are not implemented")`.
- GDI drawing (Chromium's software output device) gets no window surface for a window whose top-level window belongs to another process (`update_visible_region` in `dlls/win32u/dce.c`, `WND_OTHER_PROCESS`), so the pixels are dropped.

This is probably also why the start page's web panel stayed blank in Run 09.

## Fix
The Storyline launcher adds Chromium's `--in-process-gpu`, which runs the GPU service and compositor on a thread inside Storyline's own process, where Wine draws normally. No Articulate file is changed.

Run 09 said host-process switches are ignored because CefSharp builds Chromium's command line. That was wrong: with `--in-process-gpu` on `Storyline.exe`, no `--type=gpu-process` child starts, and the switch takes effect.

## Verified
New project, F12 Preview: the player renders with its menu (Intro Scene → Intro Slide), title, Resources, play and Next controls. With a separate GPU process the same pane was white.

## Not verified
- The start-page web panel and other CEF views after the change.
- CPU cost of compositing on Storyline's own process; with GPU acceleration already failing, this is software compositing either way.
- Preview of a project with media and animation.
