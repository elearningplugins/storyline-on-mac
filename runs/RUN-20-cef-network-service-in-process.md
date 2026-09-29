# Run 20 — CEF start-up: the network service as a thread, not another Storyline.exe

## Question
Storyline's log goes quiet for about 13 s between connecting to the Desktop Service and "A360 Version". What fills it, and can launcher switches shorten it?

## What fills the gap
An EventPipe CPU trace of one cold launch (`DOTNET_EnableEventPipe=1`, `Microsoft-DotNETCore-SampleProfiler`), main thread only. Tracing slows everything, so treat the numbers as relative:

| Main-thread work | Time |
|---|---|
| Autofac registration modules (`InitializableRegistrationModule`) | ~2 s |
| `UICommands.LoadFromAssembly`: ribbon commands | ~6.5 s |
| … of which `RuntimeModule.GetTypes()` (reflection) | ~1.9 s |
| … of which `GDICache.GetImage` → `Image.FromStream` (icons, Wine GDI+) | ~2.9 s |
| `CefSharp.Cef.Initialize` | ~2.7 s |

Before the gap, the main thread also blocks ~10 s in `RpcClient.ConnectOrWait`, waiting for the Desktop Service that Storyline starts ("Remoting service is not alive, starting service").

## Why Chromium start-up costs more here
`Program.Main` sets `BrowserSubprocessPath = Environment.ProcessPath`, so every CEF helper is another `Storyline.exe` that boots the .NET runtime again under Wine. A cold launch starts two, about the time `Cef.Initialize` runs:
- `--type=utility --utility-sub-type=network.mojom.NetworkService`
- `--type=utility --utility-sub-type=storage.mojom.StorageService`

Chromium switches on `Storyline.exe`'s command line reach CEF (Run 16). CefSharp merges `enable-features` / `disable-features` with the values Storyline sets in `DefaultCefSettings`.

## Change
The Storyline launcher adds `--enable-features=NetworkServiceInProcess2`, so the network service runs on a thread inside Storyline.

`--disable-features=StorageServiceOutOfProcess` was tried too. The merged `disable-features` list reached Chromium, but the storage helper still started, so this Chromium build ignores it. It is not in the launcher.

## Measured
Three alternating pairs of cold launches (`wineserver -k` before each), traced as above. `Cef.Initialize` is the main thread's inclusive time; "whole launch" is Storyline's first log line to `LoadRecentList() entered`.

| Pair | `Cef.Initialize` without | with | Whole launch without | with |
|---|---|---|---|---|
| 1 | 2694 ms | 1835 ms | 46.5 s | 46.1 s |
| 2 | 2337 ms | 1897 ms | 48.7 s | 46.4 s |
| 3 | 1960 ms | 1841 ms | 47.4 s | 46.0 s |
| Mean | 2330 ms | 1858 ms | 47.5 s | 46.2 s |

With the switch, only the storage helper started; without it, both. The whole-launch difference is inside the run-to-run spread seen elsewhere (22–39 s untraced), so it is likely but not proven.

## Verified
- New Project, then Preview on the Story View ribbon, launched with the switch: the player rendered with its menu (Intro Scene → Intro Slide), title, Resources, play and Next controls.
- The start screen loaded (`LoadRecentList() entered`) on every run with the switch.

## Not verified
- Web content that leans on the network stack: previews with web objects, video from URLs, the AI Assistant panel, sign-in flows inside CEF.
- If the network service crashes, it now takes Storyline down rather than restarting a helper.

## Ruled out
A macOS `sample` during `Cef.Initialize` showed most threads waiting on Wine's `virtual_mutex`. The holder was a thread in `dlopen` blocked on dyld's synchronous notification to the attached sampler, so that contention is mostly caused by `sample` itself.
