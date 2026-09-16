# Storyline 360 on macOS (Intel) via Wine — research log

Can the current Articulate 360 / Storyline 360 Windows apps run on an Intel Mac through upstream Wine — no VM, no Boot Camp, no CrossOver, no remote Windows, no licensing/auth bypass?

Full method and constraints: [docs/research-plan.md](docs/research-plan.md). Every experiment is recorded under [runs/](runs/) with sanitized logs under [logs/](logs/). Licensed binaries, Wine prefixes, and snapshots are kept outside this repo; [SHA256SUMS](SHA256SUMS) pins the exact inputs.

## Environment

| | |
|---|---|
| Host | 2019 MacBook Pro 15,4 (Core i5, Iris Plus 645), macOS 15.7.9 |
| Wine | MacPorts `wine-devel` 11.16 (`+ffmpeg +gstreamer`, binary archive), Wine Mono 11.3.0, Gecko 2.47.4 |
| MacPorts | 2.12.6 Sequoia pkg, SHA-256 + Developer ID/notarization verified |
| Input | `articulate-360.exe` (Burn 3.11.2, bundle 1.125.37980.0), SHA-256 `bc725a70…c88e9` |
| Winetricks | release 20260125, tag commit `57063f0b…` |

## Status board

| Step | Result | Run |
|---|---|---|
| Xcode CLT | Was broken (missing libc++ headers); clean reinstall fixed it | logs/macports/clt-reinstall.txt |
| MacPorts + Wine 11.16 install | OK — binary archives; only `gd2`/`graphviz` built from source | logs/macports/ |
| Burn bootstrapper UI (WPF, under Wine Mono) | **Renders correctly** | 01 |
| VC++ 2015–2022 x86 / x64 | **OK** (0x0) | 01 |
| Core MSI, stock prefix | **FAIL** 0x80070643 — `RegisterScheduledTaskAction` hits Wine stub `ITaskSettings::get_IdleSettings` (E_NOTIMPL) | 01 |
| Core MSI with `DisableNonAdminInstalls=true` | **OK** (0x0) — Articulate's documented setting skips the task | 02 |
| `Articulate 360 Desktop App.exe`, Wine Mono | **FAIL** — TypeLoadException: `EventLogInvalidDataException` missing from Mono's System.Core | 03 |
| Original EXE, real .NET 4.8 prefix | **degrades** — Burn can't host managed BA (0x8007000e), installs nothing | 04a |
| Core MSI direct, real .NET 4.8 | **FAIL** 1603 — DTF custom action can't create CLR AppDomain (0x8007000E) | 04b |
| Core MSI admin layout (`msiexec /a`) + registry import | **OK** | 04c |
| `Articulate 360 Desktop App.exe`, real .NET 4.8 | **RUNS** — service spawned, RPC OK, HTTPS OK | 04d |
| Sign-in / entitlement / catalog (Gate 1) | **PASS** via OIDC loopback fallback (custom-scheme handler timed out on macOS) | 04d |
| Restart persistence, HiDPI, Dock launcher | **OK** (`~/Applications/Articulate 360.app`) | 04e |
| Storyline install from the app | **BLOCKED** — app forces a Desktop App self-update first; update runs Burn → CLR hosting fails | 04e |
| Root cause of CLR hosting failure | **FOUND** — Wine gives 32-bit processes `0x7fff0000-0x7fffffff` (wow64 `default_zero_bits`) | 05 |
| Patched `ntdll.so` research build | **WORKS** — core MSI custom actions run; original EXE installs end-to-end under real .NET 4.8 | 06 |
| Restart persistence, HiDPI, Dock launcher | **OK** (`~/Applications/Articulate 360.app`) | 04e |
| Storyline install from the app | **BLOCKED** — app forces a Desktop App self-update first; update runs Burn → CLR hosting fails | 04e |
| Root cause of CLR hosting failure | **FOUND** — Wine gives 32-bit processes `0x7fff0000-0x7fffffff` (wow64 `default_zero_bits`) | 05 |
| Patched `ntdll.so` research build | **WORKS** — core MSI custom actions run; original EXE installs end-to-end under real .NET 4.8 | 06 |
| Storyline install (official bundle, direct) | **INSTALLED** — all 5 packages 0x0 incl. .NET Desktop Runtime 10 | 07 |
| Install via Desktop App → Installer Service | **FAIL** — "Directory has unexpected ACL" (Wine security-descriptor round-trip) | 07 |
| Storyline launch + start page | **RUNS** (CEF GPU process fails → software fallback, slow first paint) | 08 |
| New Project → text layout | **FIXED** by patch 0002 — authoring window renders, 0 exceptions | 08 |
| Preview | **FAIL** — managed NRE in `Project.PreparePreview` (no Wine call fails; origin inside Articulate) | 09 |
| Save / Player dialog / Publish | **FAIL** — managed NREs (null player), same root as Preview | 09 |
| Text box editing | FL fixed (0003), D2D shaders fixed (0004); AI writer popup layered-window loop → winemac shadow fix (0005), verifying | 11 |
| Incident | **T2 ANS2 (SSD controller) panic** during heavy `+file` tracing — tracing rules added | 09 |
| New Project load | 20.9 s → **13.7 s** warm (RNG + colour-space patches); rest is .NET JIT of IL-only assemblies | 12 |
| CEF GPU (start-page panel, browser views) | **degraded** — Wine d3d11 has no WARP device; hardware ANGLE also fails; software fallback after retries | 09 |


## Current setup (what actually runs)

- **Patched Wine**: `~/StorylineLab/wine-patched/` is a symlink mirror of `/opt/local/lib/wine` with two files replaced —
  `x86_64-unix/ntdll.so` (patch 0001) and `x86_64-windows/dwrite.dll` (patch 0002) — plus a copy of the loader and a `share`
  symlink. Built by `tools/wine-build/build-ntdll.sh`. `/opt/local` is never modified. The prefix's `system32/dwrite.dll`
  is also replaced with the patched copy.
- **Prefix**: `~/StorylineLab/prefixes/wine-dotnet48-noadmintask` — real .NET Framework 4.8 (winetricks), Windows 10 mode,
  `DisableNonAdminInstalls=true`, Articulate 360 core laid out via `msiexec /a` + registry import, Storyline installed by the
  official bundle, .NET Desktop Runtime 10 x64 from that bundle. Mac driver: `LeftCommandIsCtrl`/`RightCommandIsCtrl=y`;
  `RetinaMode` currently `n` (WPF dialogs went blank with it on); `Direct3D\renderer` unset (default GL) as of Run 09.
- **Launchers**: `~/Applications/Articulate 360.app` and `~/Applications/Storyline 360.app` (tools/launcher/) run the genuine
  EXEs on the patched Wine; `~/Applications/Articulate360Bridge.app` handles `articulate://` sign-in callbacks.

## What worked

- **Articulate 360 Desktop App signs in and shows the full catalog under Wine 11.16 + real .NET Framework 4.8** (Run 04). Desktop Service is spawned by the app; no Windows service or scheduled task needed.
- `msiexec /a` (administrative install) lays the core package out without running any custom action; the only registry the real installer writes is three small keys, imported from a prefix where it did complete.
- Articulate's own OIDC loopback fallback completes sign-in when the `articulate://` custom scheme has no macOS handler. A transport-only handler app is provided in `tools/macos-url-bridge/` for the primary path.

- Upstream Wine 11.16 from MacPorts binary archives — no source build, no Gatekeeper workarounds.
- Running the original `articulate-360.exe` unmodified. The WPF managed bootstrapper paints and runs its detect/plan/apply phases under Wine Mono.
- Pre-setting `HKLM\Software\Articulate\Common\Settings\DisableNonAdminInstalls = "true"` (REG_SZ) in the prefix before install. This is Articulate's own enterprise deployment switch; it makes the installer skip Task Scheduler registration, which is the only part of the core MSI Wine can't handle.

## What didn't

- Native CLR hosting under real .NET 4.8 in Wine: both WiX Burn's `mbahost` and DTF `SFXCA` fail with 0x8007000E creating an AppDomain, while managed EXEs run normally. This blocks the Burn UI and every DTF custom action in Articulate's MSIs. Open item — will matter for Storyline's MSI.

- Xcode CLT as found on the machine: `clang++` could not find `<initializer_list>`. Any C++ source build fails until `rm -rf /Library/Developer/CommandLineTools && xcode-select --install`.
- MacPorts `port -s` (force source build) is not needed and would be slow on this hardware; skip it unless patching Wine.
- Core MSI in a stock prefix: Wine's `taskschd` stubs `get_IdleSettings`, and Articulate's custom action (using the managed TaskScheduler wrapper) throws on it. A Wine patch returning a stub `IIdleSettings` would also fix this (not attempted; registry route was cheaper).
- Wine Mono as a stand-in for .NET Framework 4.8: good enough for the installer UI, not for the Desktop App (missing `System.Diagnostics.Eventing.Reader` types).

## Reproduce

```bash
# prerequisites (privileged): MacPorts 2.12.6, then
sudo port install wine-devel cabextract

# build prefix with real .NET 4.8 + the registry value
tools/build-prefix-dotnet48.sh wine-dotnet48-noadmintask

# run the installer with focused Wine logging
tools/run-wine-logged.sh wine-dotnet48-noadmintask burn ~/StorylineLab/inputs/articulate-360.exe
```

`tools/run-wine-logged.sh` writes a header (macOS build, Wine version, prefix, Windows build number, input hash, exit code) to each log so every run is self-describing.

## Rules kept

No Gatekeeper/SIP changes, no quarantine stripping, no `--no-sandbox`, no TLS/licensing/code-signing bypass, no patched Articulate binaries. The only change to Articulate's behavior is a registry value its own deployment guide documents.
