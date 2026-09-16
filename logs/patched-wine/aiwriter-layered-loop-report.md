# Storyline 360: the AI Assistant writer popup repaints its layered window ~37×/s while idle

**Product:** Articulate Storyline 360 (x64), build 3.125.37980.0 · **Observed:** 2026-09-15

## Summary

After **Insert → Text Box**, Storyline opens the AI Assistant writer popup — a WPF window
(`HwndWrapper[Storyline;Main;…]`, title `AiWriterWindow`, `WS_EX_LAYERED`, 800×515 px). From 0.3 s after
creation until 47 ms before it is destroyed, it calls `UpdateLayeredWindow` continuously:

| Metric | Value |
|---|---|
| Calls while the popup was open (user hands-off) | **2,087 in 56.6 s → 36.9 / s** |
| Interval between calls | median 25 ms; 65% of calls 20–29 ms, 12% 10–19 ms, 17% 30–39 ms |
| Calling thread | one thread (the WPF render thread), every call |
| Window rectangle passed | identical for every call: (235,260)–(1035,775) |
| Data pushed per frame | 800 × 515 × 4 B ≈ 1.65 MB → **≈ 61 MB/s** for a static popup |
| Other layered windows in the same session | 4–8 updates each, total (tooltips, dropdown chrome) |
| Stops when | the popup is closed (Esc): last update 36104.784, window destroyed 36104.831 |

The popup is visually static apart from a small "shimmer"/pulse; nothing the user does is required to keep
the loop running. On a stock Windows desktop DWM absorbs this; anywhere layered-window composition costs CPU
(RDP/Citrix, virtual machines, compatibility layers, integrated GPUs under load) the UI thread is starved and
the editor appears frozen until the popup is dismissed.

## Evidence (window-manager trace; first column is seconds)

```
36047.927:0808:trace:win:NtUserCreateWindowEx ex_style 0x80000, class_name L"HwndWrapper[Storyline;Main;80f0b5ce-c9d7-43f6-847d-07c20db5e728]", version <null>, window_name L"AiWriterWindow", style 0x2080000, x 2147483648, y 214748
36048.224:0678:trace:win:NtUserUpdateLayeredWindow window 0x2105f4 new_rects { window (235,260)-(1035,775), client (235,260)-(1035,775), visible (235,260)-(1035,775) }
36048.335:0678:trace:win:NtUserUpdateLayeredWindow window 0x2105f4 new_rects { window (235,260)-(1035,775), client (235,260)-(1035,775), visible (235,260)-(1035,775) }
36048.403:0678:trace:win:NtUserUpdateLayeredWindow window 0x2105f4 new_rects { window (235,260)-(1035,775), client (235,260)-(1035,775), visible (235,260)-(1035,775) }
36048.778:0678:trace:win:NtUserUpdateLayeredWindow window 0x2105f4 new_rects { window (235,260)-(1035,775), client (235,260)-(1035,775), visible (235,260)-(1035,775) }
36048.877:0678:trace:win:NtUserUpdateLayeredWindow window 0x2105f4 new_rects { window (235,260)-(1035,775), client (235,260)-(1035,775), visible (235,260)-(1035,775) }
36048.969:0678:trace:win:NtUserUpdateLayeredWindow window 0x2105f4 new_rects { window (235,260)-(1035,775), client (235,260)-(1035,775), visible (235,260)-(1035,775) }
... (2087 calls total) ...
36104.707:0678:trace:win:NtUserUpdateLayeredWindow window 0x2105f4 new_rects { window (235,260)-(1035,775), client (235,260)-(1035,775), visible (235,260)-(1035,775) }
36104.740:0678:trace:win:NtUserUpdateLayeredWindow window 0x2105f4 new_rects { window (235,260)-(1035,775), client (235,260)-(1035,775), visible (235,260)-(1035,775) }
36104.784:0678:trace:win:NtUserUpdateLayeredWindow window 0x2105f4 new_rects { window (235,260)-(1035,775), client (235,260)-(1035,775), visible (235,260)-(1035,775) }
36104.806:0808:trace:win:user_destroy_window (0x2105f4)
```

Interval histogram (ms → count): 10–19: 247 · 20–29: 1367 · 30–39: 363 · 40–49: 63 · 50–59: 17 · ≥60: 24

For comparison, all `UpdateLayeredWindow` calls in the session by window:
`AiWriterWindow`: 2087 · four other popups/tooltips: 8, 8, 8, 8 · one more: 4.

## Likely cause

`AllowsTransparency="True"` on the popup forces WPF into software rendering with a full-window
`UpdateLayeredWindow` on every render tick; any continuously running animation in that window
(shimmer, pulse, spinner, caret) re-pushes the entire frame at ~30–40 Hz even though only a few pixels change.

## Suggestions

1. Render the popup without `AllowsTransparency` — an opaque window with rounded corners via
   `DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE)`, or host it as a child element of the main window.
2. If transparency is required: stop the animation when idle, or cap it
   (`Timeline.DesiredFrameRate`), so the window is not repainted while the user is typing elsewhere.
3. Offer a per-user setting to disable the AI writer popup. **Storyline Options has no such switch** for this
   account (checked build 3.125.37980.0).

## Method / environment

Win32 window-manager tracing (timestamped `NtUserCreateWindowEx` / `NtUserUpdateLayeredWindow` /
destroy events) captured while running Storyline under a Windows compatibility layer on macOS. The
composition cost is environment-specific; the ~37 Hz repaint loop is Storyline's own behaviour and is
platform-independent.
