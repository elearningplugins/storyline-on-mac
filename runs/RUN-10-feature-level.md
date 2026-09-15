# Run 10 — The graphics root cause: wined3d caps this Mac at D3D feature level 9_3

## Probe (tools/probes/d3dprobe.c, run under Wine)
GL and Vulkan renderers alike: `D3D11CreateDevice → S_OK at level 0x9300`; `D3D10CreateDevice1(10_0/10_1) → E_FAIL`,
with `winediag: None of the requested D3D feature levels is supported on this GPU with the current shader backend`.
Consequences: Direct2D's DC render target needs a D3D10.1 device → `CreateDCRenderTarget E_FAIL` (Articulate's text engine,
thumbnails, player rendering, and therefore Save/Preview/Player/Publish nulls); Chromium/ANGLE needs FL ≥ 10 → GPU process dies.

## Why (tools/probes/vkfeat2.c — Vulkan device features as seen through winevulkan/MoltenVK)
Intel Iris Plus 645 via MoltenVK is missing exactly: `geometryShader`, `pipelineStatisticsQuery`, `shaderCullDistance`.
Everything else wined3d requires for FL 10, 10_1, 11 and 11_1 is present (multiViewport, depthClamp, clip distance,
draw parameters, vertex divisor, cube arrays, indirect draws, atomics, gather, tessellation). Metal has no geometry shaders,
so no Wine-on-Mac Vulkan setup will ever pass the stock gate.
The GL backend is separately stuck at 9_3 because macOS only offers a legacy 2.1 context to wined3d's path.

## Fix (patch 0003, research switch)
`dlls/wined3d/adapter_vk.c`: when `WINE_D3D_FL_RELAX=1` is set, `feature_level_10_supported()` no longer requires the three
missing features. Result: `D3D11CreateDevice → level 0xb100 (11_1)`, `D3D10CreateDevice1 10_1/10_0 → S_OK`.
Caveat: an app that actually uses geometry shaders, cull distance, or pipeline-statistics queries will fail at that point
instead of at device creation. Direct2D and ANGLE use none of them. The switch is set only by the launchers/bridge.
Prefix renderer set back to `vulkan` (WPF text also renders correctly there, and GL cannot exceed 9_3 anyway).
