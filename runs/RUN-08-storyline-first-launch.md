# Run 08 — Storyline 360 first launch (patched Wine)

- `Storyline.exe` launches from the signed-in prefix: main process + CEF helpers (`--type=gpu-process`, utility processes),
  `Articulate.Watchdog.exe`. Storyline's log (Storyline_STABLE.log) shows only feature-flag warnings.
- Embedded browser is **CefSharp/Chromium** (`CefSharp.BrowserSubprocess.exe`, Storyline-CEF_*.log) — not WebView2.
- **Start page renders; New Project can be clicked.**

## Blocker 1 — CEF GPU process
`eglInitialize D3D11 failed … No available renderers … Exiting GPU process due to errors during initialization`, repeated;
gpu-process pegged ~75% CPU and the UI beachballed on first launch. `HKCU\Software\Wine\Direct3D\renderer=vulkan` (MoltenVK)
did not help (D3D11Warp also fails). Chromium falls back to software after the GPU process gives up.
logs/patched-wine/storyline-cef-gpu-errors.txt. Candidate: launch with `--disable-gpu` (CEF reads the host process
command line) — not yet tried.

## Blocker 2 — DirectWrite justification (first authoring-path failure)
New Project → creating the first text box → Articulate's DirectWrite text engine (SharpDX) calls
`IDWriteTextAnalyzer1::GetJustificationOpportunities` → Wine stub → `E_NOTIMPL` → error report dialog.
Fix: tools/wine-patches/0002-dwrite-implement-IDWriteTextAnalyzer1-justification.patch implements
GetJustificationOpportunities (blank/inter-character opportunities; spaces detected from the text via the cluster map because
Wine's shaper never sets SCRIPT_JUSTIFY_BLANK), JustifyGlyphAdvances (priority-ordered proportional expansion/compression +
residual), GetJustifiedGlyphs (pass-through, no kashida). Built as PE `dwrite.dll` (mingw), installed into the mirror and
into the prefix's system32 copy. Result: pending.

## Usability notes
- ⌘C/⌘V do not act as Ctrl-C/V by default; set `HKCU\Software\Wine\Mac Driver\LeftCommandIsCtrl=y` (+Right). Done.
- Storyline's error report opens in Wine's Notepad; select-all + Ctrl-C works to copy it out.

## Result with patch 0002
- New Project → **project created, full authoring window renders**: ribbon (Home/Insert/Slides/Design/Transitions/Animations/
  View/Help), Story View with scene + slide, Triggers panel, Slide Properties, status bar (1920×1080, "Clean" theme).
- 0 managed exceptions in the Wine log after relaunch; dwrite silent. Text layout path (SharpDX → IDWriteTextAnalyzer1) works.
- Main process ~118% CPU while loading: CEF GPU process crashed/restarted 26× (ANGLE D3D11 init) before Chromium gave up;
  plus wined3d for WinForms/WPF surfaces. Remaining fixmes are noise (DPI hosting behavior stubs, EMF record types for
  ribbon icons, font charset). logs/patched-wine/storyline-authoring-fixme-summary.txt
- Next: launch with `--disable-gpu` to skip the GPU retry loop; then Gate 2 items (text box, save/reopen, preview, publish).
