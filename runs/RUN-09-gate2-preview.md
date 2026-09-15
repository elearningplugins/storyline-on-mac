# Run 09 — Gate 2: Preview fails (NullReferenceException in Project.PreparePreview); CEF GPU root cause

## Preview
- Slide → Preview → Articulate error dialog: `NullReferenceException` at
  `Articulate.Design.Project.PreparePreview(IPlayerContentProvider provider, …)` (outer stack only, 3 reproductions).
- Related symptoms at project load: `StoryBoardItemBase.DrawSlideThumbnail: Slide thumbnail is null` and five accessibility
  checkers throwing NRE on player properties (DisabledAccessibilityControls, SkipNav, PlaybackSpeed, Orientation, PlayPause).
- Wine-side tracing (seh, d2d, d3d11, dxgi): D2D factories are created but no render target is ever made; a D3D10.1 device is
  created successfully; `CheckInterfaceSupport(ID3D10Device)` succeeds (MoltenVK FL ≥ 10). **No access violation and no
  NRE-coded (0x80004003) CLR exception appears in the trace at all**, so the null is hit in pure managed code — an uninitialised
  player/renderer object, not a failed Wine call. Origin not identifiable from outside Articulate's assemblies.
  CLR exception mix during the session: 15× 0x80131622 (ObjectDisposed), 8× 0x80131515, 6× 0x80131500, 6× 0x80070002
  (FileNotFound — two are the missing WinRT `Windows.UI.Notifications.ToastNotificationManager`), 5× 0x8013153B, 5× 0x80131509.
  logs/patched-wine/storyline-preview-diag-summary.txt
- Articulate.Watchdog reports "hang detected" during slow startups and phones home — harmless but noisy.

## CEF GPU process — root cause
Chromium (CefSharp) first tries ANGLE-on-D3D11 hardware, then **D3D11 WARP**. Wine: `fixme:d3d11:d3d11_create_device WARP
driver not implemented, falling back to hardware`; both fail → `eglInitialize … No available renderers` → GPU process exits and
Chromium relaunches it ~12–26× before giving up. Host-process `--disable-gpu` is ignored (CefSharp builds Chromium's command
line itself). Consequences: the start-page web panel stays blank; heavy CPU for the first minutes.
Options: (a) implement a WARP-style software device path in Wine d3d11 (upstream gap); (b) find where CefSharp takes its
switches (CefSettings in Articulate code — not modifiable under the plan rules); (c) accept software fallback.

## Still OK
New Project, ribbon, Story View, slide editing UI, text layout (dwrite patch) — no Wine-side errors.
