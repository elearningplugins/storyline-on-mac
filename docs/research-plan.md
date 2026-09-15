# Storyline 360 on macOS without Windows: workaround research plan

Last researched: September 14, 2026

## Goal and non-negotiable constraints

The goal is to discover, build, and validate a workaround that runs the current Storyline 360 Windows application directly on this Intel Mac through a macOS compatibility layer.

This project explicitly excludes:

- virtual machines of any kind
- Boot Camp or another Windows installation on an internal or external disk
- remote Windows computers, cloud PCs, and published remote applications
- the CrossOver trial or another time-limited commercial runtime
- replacing Storyline with another authoring product
- bypassing Articulate authentication, licensing, code signing, or security controls

This is therefore a **Wine compatibility-engineering project**, not a search for another place to run Windows.

No step in this plan installs or boots Windows—internally, externally, virtually, remotely, or in the cloud. Windows application runtimes inside a Wine prefix are compatibility components, not a Windows operating-system installation. The plan does not require CrossOver. Sikarugir is also parked for this iteration; it is neither the launcher nor an indirect dependency.

## The central dependency gate

The installed **Articulate 360 Desktop App and its service must work first**. Articulate's deployment documentation says its authoring applications require the Articulate 360 core component. Storyline is not considered viable unless the desktop app can:

1. launch reliably
2. keep its desktop and installer services running
3. authenticate through the normal Articulate sign-in flow
4. recognize the user's subscription/entitlement
5. display and manage Storyline
6. survive a macOS restart and an Articulate update

If that installed application cannot complete those operations under Wine, this plan does not claim that Storyline works.

There is a useful technical distinction:

- `articulate-360.exe` is a **WiX Burn bootstrapper**. Its UI or dependency chain may fail even when the software inside it is runnable.
- `Articulate.360.Package.msi` installs the actual **Articulate 360 Desktop App, desktop service, and installer service**.

Bypassing a broken Burn wrapper with Articulate's own MSI is an installer workaround, not bypassing the required desktop app. Failure of both the original EXE path and the direct-MSI path—especially at service or authentication startup—is the meaningful hard stop.

## Evidence already collected from this Mac

Read-only checks found:

| Item | Finding | Relevance |
|---|---|---|
| Hardware | 2019 Intel MacBook Pro (`MacBookPro15,4`), four-core Core i5, 16 GB RAM | Windows x86/x64 instructions run natively on the CPU; no Rosetta or ARM translation is involved |
| Host | macOS 15.7.9 (`darwin 24`), Intel x86_64 | Meets the current MacPorts `wine-devel` requirement of Darwin 19 or later |
| Wine software | No Wine or CrossOver installation detected; MacPorts is not installed | Experiments can start without an unknown existing prefix or package-manager state |
| Input | `~/Downloads/articulate-360.exe`, about 60 MB | This is the desktop bootstrapper, not Storyline |
| Input SHA-256 | `bc725a70f065ef6ed5bd9ab689bf39423f051d030aacc827d90ed166a07c88e9` | Locks the baseline to the exact tested installer |

The installer was extracted read-only. Its manifest identifies WiX Burn 3.11.2 and bundle version `1.125.37980.0`. It contains:

- VC++ redistributables for x86 and x64
- a web installer for .NET Framework 4.8
- `Articulate.360.Package.msi`, version `1.125.37980.0`

It does **not** contain Storyline. The core MSI contains a Windows-heavy application stack:

- WPF and WinForms assemblies
- DirectWrite-dependent Articulate text components
- Windows services and a scheduled installer task
- OIDC/IdentityModel authentication components
- Chromium attribution files, indicating an embedded Chromium-family dependency somewhere in the application
- registry writes under `HKLM\Software\Articulate`

The extracted MSI inventory did not expose a literal `WebView2`, `msedgewebview2`, `CefSharp`, or `libcef` filename. A Chromium credits file alone does not identify the hosting engine, so WebView2-specific changes would currently be guesswork.

These are the actual compatibility risks. DirectX game patches are not the main problem.

## Current external evidence

- Articulate supports 64-bit Windows 10/11 and lists .NET Desktop Runtime 10, .NET Framework 4.8, VSTO 2010, and VC++ 2019 as installation dependencies. Its deployment package includes separate core and Storyline x64 MSIs ([Articulate deployment guide](https://cdn.articulate.com/assets/kb/360/deployment/articulate-360-deployment-guide.html)).
- CodeWeavers rates Articulate 360 **Will Not Install**, last tested with CrossOver 25.1.0. That result is based on one reported test and has no current advocates ([compatibility entry](https://www.codeweavers.com/compatibility/crossover/articulate-360)).
- The CodeWeavers result is still useful negative evidence, but this plan does not use the CrossOver trial. Its current Wine-derived source is relevant only when comparing missing APIs.
- Microsoft describes .NET Desktop Runtime 10 as the Windows runtime for WPF and WinForms applications; installing the cross-platform base `.NET Runtime` is not sufficient ([Microsoft .NET 10 Windows notes](https://github.com/dotnet/core/blob/main/release-notes/10.0/install-windows.md)).
- Microsoft states that WPF and WinForms run only on Windows. Wine must therefore reproduce their Windows APIs; installing macOS .NET cannot help ([dotnet/wpf](https://github.com/dotnet/wpf)).
- MacPorts' current `wine-devel` Portfile builds upstream Wine 11.16 on x86_64 macOS with `--enable-archs=i386,x86_64`, and its Intel defaults include GStreamer and FFmpeg. It also pins and verifies the Wine source plus its dependencies ([MacPorts Portfile](https://github.com/macports/macports-ports/blob/master/emulators/wine-devel/Portfile)).
- Homebrew disabled both current `wine-stable` and `wine@staging` casks on September 1, 2026 because they fail Gatekeeper checks. Do not weaken Gatekeeper merely to use those prebuilt bundles ([stable cask](https://github.com/Homebrew/homebrew-cask/blob/HEAD/Casks/w/wine-stable.rb), [staging cask](https://github.com/Homebrew/homebrew-cask/blob/HEAD/Casks/w/wine@staging.rb)).
- Kegworks is from the same wrapper lineage now superseded by Sikarugir, Whisky is archived and targets Apple Silicon, and GPTK is Apple-Silicon/game-oriented. None improves the installer/service/WPF/authentication problem on this Intel Mac, so they are not part of the current matrix.

No public source currently documents a successful, modern Storyline 360 authoring session under Wine or CrossOver. The plan must produce that evidence rather than assume success from a launcher window.

## What the GitHub research changes

The useful GitHub material is not an existing Storyline recipe—repository and code searches found no maintained Articulate/Storyline Wine project. It is a set of reusable techniques and several concrete warnings:

| Finding | What to use or learn | Change to this plan |
|---|---|---|
| Current Winetricks `master` has separate `dotnet10` and `dotnetdesktop10` verbs, but release `20260125` predates both | The desktop verb installs Microsoft Windows Desktop Runtime 10 for both x86 and x64 in a 64-bit prefix; the base runtime verb is not equivalent. The current verb is pinned to 10.0.0, however | Use the verb as a reviewed installation reference, not as the preferred download source. Resolve the current serviced Desktop Runtime from Microsoft's release metadata, verify its published hashes, and never substitute `dotnet10` |
| The Winetricks `dotnet48` implementation deliberately switches the prefix to Windows 7 and leaves it there | A later installer can fail its OS check even though .NET 4.8 installed correctly | Restore Windows 10 mode after `dotnet48`, then query and record `CurrentBuildNumber` before running Articulate |
| Current Wine implements parts of Task Scheduler registration, but `IRegisteredTask::Run` returns `E_NOTIMPL`; task action and trigger parsing are still stubs | Articulate's MSI can appear to register its Installer Service task even though the task cannot execute | Treat the scheduled task as a predicted blocker. Capture its exact executable, arguments, working directory, account, trigger, and restart behavior; if necessary, reproduce only that launch behavior with a macOS prefix-start hook |
| Microsoft's WebView2 Wine request remains open; reports show that installation can succeed while current WebView2 content renders black | “Runtime installed” is not proof of a usable authentication surface | Do not install WebView2 speculatively. First identify the browser engine from process names, loaded modules, and installed files; if WebView2 is actually used, add a dedicated render-and-navigation gate |
| A Wine Mono/WebView2 assertion reported in 2025 was fixed in Wine Mono 10.2.0 | MacPorts currently pairs `wine-devel` with Wine Mono 11.3.0, so that old assertion should already be fixed | Do not carry the obsolete custom Wine Mono patch into the first test; verify the installed Mono port/version instead |
| Two Fusion 360 Wine projects route an OAuth custom-URI callback from the host browser back to the genuine Windows identity executable | The same architecture may solve an Articulate callback handoff without bypassing authentication | Build a macOS URL-handler bridge only if logs prove Articulate uses a custom scheme and Wine loses that callback; pass it to the installed Articulate handler in the same prefix |
| Microsoft's WPF samples now target .NET 10, and the .NET SDK supports `EnableWindowsTargeting=true` on macOS | A small open-source probe can test WPF, DirectWrite, networking, and media independently of proprietary Articulate code | Add locally built runtime probes before blaming Articulate or patching Wine |
| A current Lightroom-on-Wine project uses clean-prefix checkpoints, focused load traces, and a post-`dotnet48` Windows-version reset | Its individual Adobe DLL shims are application-specific, but its experimental discipline is reusable | Borrow its sequencing and evidence model, not its DLL replacements, DXVK settings, or security-sensitive browser flags |

Do **not** copy `WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--no-sandbox` from Wine recipes. It disables a browser security boundary and is not an acceptable fix for an authenticated Articulate session. Likewise, do not pin an obsolete WebView2 build simply because it paints under Wine.

As of this research date, Microsoft's checked-in .NET 10 release metadata names `10.0.12` as the latest security release and publishes Windows Desktop x86/x64 URLs plus SHA-512 hashes. This metadata is a better input to a local resolver than hard-coded Winetricks 10.0.0 URLs. The resolver must record the selected version and hashes so a later run does not silently change inputs.

## Definition of success

A no-VM workaround is successful only if all three gates pass.

### Gate 1: Articulate 360 Desktop

- Clean install completes, either through the original EXE or the official core MSI.
- Desktop App, Desktop Service, and Installer Service start and remain running.
- Normal browser/OIDC authentication completes.
- Subscription state and application catalog load.
- Storyline appears as entitled and can be installed or recognized.
- Restart and update do not break the prefix.

### Gate 2: Storyline authoring

- Storyline launches from the Articulate desktop app.
- A project can be created, saved to Wine's `C:` drive, closed, reopened, and edited.
- Slides, layers, states, variables, triggers, and timeline objects work.
- Images, audio, and H.264/AAC video insert and play.
- Slide, scene, and full-project preview work.
- SCORM 1.2 and SCORM 2004 publishing complete and the output launches.
- Review 360 publishing works if it is part of the required workflow.

### Gate 3: stability and maintainability

- A two-hour authoring session completes without a crash or damaged project.
- Twenty save/preview cycles complete.
- The result survives a reboot and one Articulate update.
- The exact setup can be recreated from scripts and documented inputs in a clean prefix.

Launching the installer, desktop shell, or Storyline window by itself does not pass these gates.

## Tooling strategy

Use the smallest tool set that answers a specific question:

| Tool | Role in this project |
|---|---|
| MacPorts 2.12.6 | Reproducible source-build driver and dependency manager; use the signed Sequoia package or build MacPorts itself from its tagged source |
| MacPorts `wine-devel` 11.16 | Direct upstream-Wine baseline for this Intel Mac; its Portfile enables i386+x86_64 and the native macOS driver, with GStreamer and FFmpeg enabled by default on Intel |
| [Winetricks](https://github.com/Winetricks/winetricks) | Controlled installation of .NET Framework 4.8, VC runtimes, fonts, and Wine settings; its unreleased `dotnetdesktop10` verb is a useful recipe reference but currently downloads the original 10.0.0 runtime |
| [msitools](https://github.com/GNOME/msitools) | Inspect MSI tables, custom actions, services, conditions, and files without executing them |
| `cabextract` | Extract Microsoft CAB payloads used by prerequisites and MSI packages |
| [Wine source](https://gitlab.winehq.org/wine/wine) and a local MacPorts overlay | Locate, apply, build, and test a narrowly identified missing-API patch without installing CrossOver or a wrapper manager |
| `shasum`, `file`, `codesign`, `otool`, `strings` | Verify inputs and inspect macOS/Windows binaries |

Do not test Proton, GPTK, Whisky, DXVK, or D3DMetal unless a log proves a Direct3D problem. They add game-oriented variables before the installer, service, WPF, and authentication gates are solved.

### Runtime trust policy

- Do not download anything from `sikarugir.com`, and do not install Sikarugir or Kegworks in this iteration.
- Do not use Homebrew's disabled Wine casks or manually clear quarantine to force them through Gatekeeper.
- Obtain MacPorts 2.12.6 from its official GitHub release. For macOS 15, pin `MacPorts-2.12.6-15-Sequoia.pkg` and verify SHA-256 `2d6d58ff3ff60e70f8dc05cb2df9df3137e3d7c0c6d6f6236d68c8ba03343e34` against GitHub's asset metadata. Also verify the installer signature before opening it.
- Force the Wine port itself to build from reviewed source with `port -s`; preserve the Portfile, Wine source SHA/hash, applied MacPorts patch, dependency versions, and build log.
- Never run `spctl --master-disable`, alter SIP, or use `xattr` to remove quarantine as a substitute for verifying a download.

## Reproducible lab layout

Keep licensed binaries and large prefixes outside this Git repository. Add only scripts, hashes, sanitized logs, and notes to the repository.

```text
StorylineLab/
  inputs/
    SHA256SUMS
    articulate-360.exe
    deployment-package/
    microsoft-prerequisites/
  prefixes/
    wine-burn-clean/
    wine-msi-clean/
    wine-sourcepatch-clean/
  logs/
    burn/
    prerequisites/
    core-msi/
    desktop-app/
    storyline/
  prefix-snapshots/
```

Create repository-side helpers in a later implementation step:

```text
tools/storyline-lab/
  inventory-mac.sh
  hash-inputs.sh
  inspect-burn.sh
  inspect-msi.sh
  run-wine-logged.sh
  probe-desktop-processes.sh
  probe-dotnet-runtimes.sh
  resolve-dotnet-desktop10.sh
  probe-wpf10/
  probe-task-scheduler.ps1
  macos-url-bridge/
  collect-wine-failure.sh
  acceptance-checklist.md
```

Every run record must include the macOS build, MacPorts/Wine versions and source hashes, prefix path, Windows compatibility mode, installer hashes, prerequisite order, first failing action, exit status, and log location.

## Phase 0 — Obtain the actual Storyline payload

The existing EXE can test the desktop bootstrapper and online application-management flow, but it cannot support a decomposed Storyline experiment by itself.

1. Sign into the licensed Articulate account on macOS.
2. Download the official deployment files from `https://id.articulate.com/redirect/downloads/all`.
3. Confirm the package contains:
   - `Articulate.360.Package.msi`
   - `Articulate.Storyline_x64.Package.msi`
   - the Storyline x64 thumbnail-handler MSI
4. Obtain the prerequisites from Microsoft, not mirrors:
   - .NET Framework 4.8 offline installer
   - .NET Desktop Runtime 10 x64
   - VC++ 2015–2022 x86 and x64 redistributables
   - Visual Studio 2010 Tools for Office Runtime
5. Hash every input and record its version.
6. Pin any GitHub tool to a commit. Record the upstream URL, commit SHA, source hash, license, and whether it is a release or unreleased code.
7. For .NET Desktop 10, have the resolver read Microsoft's official `release-notes/10.0/releases.json`, select the current Windows Desktop x86/x64 installers, and verify the published SHA-512 values before either EXE runs.

The deployment package does not remove the desktop-app gate. It lets the test separate “Burn cannot orchestrate installation” from “Articulate's installed components cannot run.”

**Phase exit:** all official MSI and prerequisite inputs are present and checksummed.

### Phase 0A — Build a static compatibility map

Use msitools on macOS before running either MSI. Export at least `Property`, `LaunchCondition`, `CustomAction`, `InstallExecuteSequence`, `ServiceInstall`, `ServiceControl`, `Registry`, `Binary`, and any WiX scheduled-task tables. Also list the MSI streams and packaged files.

Representative read-only commands are:

```bash
msiinfo tables Articulate.360.Package.msi
msiinfo export Articulate.360.Package.msi CustomAction
msiinfo export Articulate.360.Package.msi InstallExecuteSequence
msiinfo export Articulate.360.Package.msi ServiceInstall
msiinfo export Articulate.360.Package.msi ServiceControl
msiinfo streams Articulate.360.Package.msi
msiextract --list Articulate.360.Package.msi
```

Generate a machine-readable map from each custom action to its source binary, condition, sequence, deferred/immediate context, and expected side effects. Flag actions that create services, scheduled tasks, protocol handlers, browser components, or machine-wide registry keys. This turns a later MSI error into a named action rather than a generic installer failure.

## Phase 1 — Direct Wine 11.16 baseline with the original EXE

1. Install Xcode Command Line Tools if they are absent. Record `xcode-select -p` and `clang --version`; do not silently switch SDKs during the experiment.
2. Install the official MacPorts 2.12.6 Sequoia package after its SHA-256 and Apple package signature checks pass. The package is a macOS build tool, not Windows or a VM.
3. Sync the official ports tree, save the exact `wine-devel` Portfile and its tree commit, inspect the planned dependency/variant graph with `port deps wine-devel` and `port variants wine-devel`, then build Wine locally with `sudo port -s install wine-devel`. Do not add the CrossOver subport or Gcenx overlay.
4. Confirm `wine --version` reports the expected Wine 11.16 build, `port installed wine-devel` reports the selected variants, and Wine Mono 11.3.0 is installed. Save `port -v installed requested` and the build log.
5. Create a clean direct prefix rather than a wrapper: `WINEARCH=win64 WINEPREFIX="$STORYLINE_LAB/prefixes/wine-burn-clean" wineboot -u`. Confirm the prefix is new and contains no files copied from another prefix.
6. Set Windows 10 mode in `winecfg`. Do not install DXVK, DXMT, D3DMetal, or game patches.
7. Enable focused channels with `WINEDEBUG=+timestamp,+pid,+tid,+seh,+loaddll,+msi,+service` and run the exact checksummed `articulate-360.exe` with that same `WINEPREFIX`.
8. Record the first failing package or action rather than changing several settings at once.
9. Before accepting an OS-version error at face value, query `HKLM\Software\Microsoft\Windows NT\CurrentVersion` and save `ProductName`, `CurrentVersion`, and `CurrentBuildNumber` in the run record.

Classify the result:

| Result | Next step |
|---|---|
| Burn never paints | Test managed-bootstrapper/.NET Framework initialization, then move to direct MSI |
| VC++ package fails | Install the same redistributable explicitly in a fresh prefix, then retry once |
| .NET Framework 4.8 fails | Compare the official offline installer with current Winetricks `dotnet48` in separate clean prefixes |
| Core MSI custom action fails | Inspect that action and MSI conditions with msitools; continue only if the action is provably nonessential |
| EXE completes | Proceed immediately to the Desktop App gate; installation alone is not a meaningful win |

Do not layer fixes into this baseline prefix. Snapshot it after failure and preserve it as evidence.

## Phase 2 — Bypass only the Burn wrapper

Create a second clean 64-bit prefix at `prefixes/wine-msi-clean`. Install one item at a time, snapshotting the prefix after each successful stage:

1. VC++ x86 redistributable, needed by the 32-bit launcher components.
2. VC++ x64 redistributable.
3. .NET Framework 4.8.
4. Reset the prefix to Windows 10 mode because Winetricks `dotnet48` sets Windows 7 during installation and does not restore it.
5. Verify .NET Framework 4.8 with Winetricks' verifier or a minimal Framework 4.8 WPF probe.
6. `Articulate.360.Package.msi` with verbose MSI logging.

Representative command shapes are:

```bash
wine vc_redist.x86.exe /install /quiet /norestart
wine vc_redist.x64.exe /install /quiet /norestart
winetricks -q dotnet48 corefonts
winetricks -q win10
wine msiexec /i Articulate.360.Package.msi /L*v core-msi.log
```

These are templates; the implementation script must resolve the MacPorts Wine binaries explicitly and bind Winetricks to that exact `WINEPREFIX`. Never mix Wine builds inside one prefix.

Inspect the verbose log before bypassing an MSI action. Permissible workarounds include:

- supplying a missing official Microsoft runtime
- correcting a path or Windows-version detection value
- pre-creating an expected ordinary directory or registry value
- skipping the Storyline thumbnail shell extension during early testing
- applying an upstream Wine fix for an unimplemented API

Out of scope:

- removing authentication or entitlement checks
- disabling code-signature or TLS validation
- patching Articulate executables or DLLs
- skipping the Desktop App, Desktop Service, or Installer Service requirement
- disabling updates permanently to hide an unstable result

**Phase exit:** the actual Articulate Desktop App and its required services are installed. If the MSI cannot install them after the dependency comparison, document the exact blocker and move to Phase 5 only when it maps to a known Wine fix.

### Phase 2A — Isolate WPF from Articulate

Before modifying proprietary binaries, add two tiny diagnostic applications under `tools/storyline-lab/`:

1. A .NET 10 WPF probe derived from Microsoft's MIT-licensed WPF samples. Build it on macOS with `EnableWindowsTargeting=true` and target `win-x64`.
2. Optional .NET Framework 4.8 verification: run Winetricks' verifier first. Add a source-built Framework 4.8 WPF probe only if it can be reproduced on macOS from reviewed reference assemblies; do not download an opaque test executable.

The .NET 10 probe must run both framework-dependent and self-contained builds. That separates “Desktop Runtime installation is broken” from “Wine's WPF/DirectWrite implementation is broken.” Keep the probes visually simple and test one subsystem at a time.

Inside the prefix, record:

```text
dotnet --list-runtimes
Microsoft.NETCore.App 10.x
Microsoft.WindowsDesktop.App 10.x
```

In a 64-bit prefix, verify the expected x64 runtime and any x86 runtime required by the desktop launcher. A successful installer exit code without `Microsoft.WindowsDesktop.App` in the runtime list is a failure.

## Phase 3 — Prove the Articulate 360 Desktop gate

This is the decisive stage requested for the project.

1. Start the Desktop Service and Installer Service through their normal installed registrations.
2. Export the Articulate scheduled-task definition and compare it with the MSI custom-action inputs. Confirm whether Wine preserved its trigger and executable action rather than trusting the custom action's success code.
3. Attempt the normal task start once. Upstream Wine 11.16 still has `IRegisteredTask::Run`, action, and trigger gaps, so failure here is predicted rather than evidence that the MSI never installed.
4. If Task Scheduler is the only blocker, create a narrowly scoped macOS launch hook that starts the **real installed** `Articulate 360 Installer Service.exe` with the exact vendor-supplied arguments in the same prefix. The hook must provide equivalent start, restart, stop, logging, and update behavior; it must not replace the Articulate service executable.
5. Confirm the desktop and installer services remain running for at least ten minutes and after `wineserver` restart.
6. Launch `Articulate 360 Desktop App.exe` normally.
7. Complete the official OIDC/browser sign-in flow.
8. Confirm the application catalog, account identity, subscription entitlement, and Storyline status load.
9. Start a Storyline install from the desktop app and capture its download/install logs.
10. Restart macOS, relaunch the prefix through the same script, and repeat the account/catalog check.

Failure guide:

| Failure boundary | Investigation |
|---|---|
| Windows service registration/start | Reduce to the failing service executable; find the first unimplemented Wine service-control/API call |
| Scheduled installer task | Compare its XML/action with current Wine's Task Scheduler stubs; if the task merely starts the real installer service, reproduce that lifecycle with a reversible macOS prefix hook and retest updates |
| OIDC callback never reaches the app | Determine whether it is a loopback redirect or custom URI. For a custom URI only, register a minimal macOS handler that validates an allowlisted scheme and forwards the untouched callback to the genuine Articulate identity executable in the already-running prefix |
| Browser/authentication area is blank | Fingerprint the browser component first. Do not infer WebView2 from a Chromium credit file; capture process names, runtime directories, modules, and renderer logs |
| Confirmed WebView2 process exits or paints black | Run a minimal WebView2 probe under the same Wine build. Do not use an obsolete runtime, disable its sandbox, or weaken TLS as a workaround |
| TLS/account endpoint fails | Verify certificate store and current TLS without disabling verification |
| Catalog loads but install fails | Capture the official Storyline payload and installer log; compare with the deployment MSI |

**Hard gate:** if the installed desktop app cannot launch, authenticate, recognize entitlement, and manage Storyline after targeted Wine fixes, Storyline is rejected under the no-VM constraint. Directly starting an extracted Storyline executable does not override this gate.

The URL bridge, if needed, is transport only. It must never parse, store, rewrite, or print authorization codes, state parameters, access tokens, or callback query strings. Implement it as a small macOS `.app` with an allowlisted `CFBundleURLTypes` entry, route to one pinned prefix and executable, reject unexpected schemes, and test it first with a dummy URL containing no credentials.

## Phase 4 — Install and validate Storyline only after Gate 1 passes

Prefer installation initiated by the working Desktop App. If its download succeeds but Burn/MSI orchestration fails, use the official deployment MSI while the authenticated desktop components remain installed and working.

1. Install the current serviced .NET Desktop Runtime 10 x86/x64 using Microsoft's official release metadata, URLs, and hashes. Keep the pinned Winetricks `dotnetdesktop10` implementation as a recipe reference or fallback, because its current static version is 10.0.0. Do not use the base `dotnet10` verb as a substitute.
2. Install VSTO 2010 if required by the Storyline MSI or a tested workflow.
3. Install `Articulate.Storyline_x64.Package.msi` with a verbose log.
4. Defer the thumbnail-handler MSI until the main application passes a first launch.
5. Launch Storyline from the Desktop App, not from an extracted-file directory.
6. Run the complete authoring, media, preview, publish, soak, restart, and update gates.

The .NET Desktop 10 step is distinct from macOS .NET and from .NET Framework 4.8. It supplies the Windows WPF/WinForms runtime that Wine must host.

## Phase 5 — Direct Wine update and source-patch loop

Do not repeat random prefix tests. Enter this phase only with a specific first exception, missing import, or Wine `fixme`/`unimplemented` boundary from Phases 1–4.

### 5A. Upstream Wine comparison

1. Keep MacPorts `wine-devel` 11.16 and its clean prefixes as the fixed binary baseline.
2. When a specific failure is identified, check whether the next upstream Wine release or a post-11.16 commit changes the implicated module. Do not update simply because a newer build exists.
3. Build the candidate from a pinned upstream Wine commit with the same MacPorts configuration and dependency set.
4. Recreate the same 64-bit prefix and exact prerequisite order.
5. Run only the smallest test that reproduces the baseline failure. If it passes, run the Desktop gate and complete acceptance suite.

Do not package a `.app` until the full suite passes. A launcher makes startup convenient; it does not improve compatibility.

### 5B. Wine source research

For a reproducible missing API:

1. Search WineHQ GitLab, Wine commits, and CodeWeavers' published Wine source using the exact function and exception code.
2. Verify whether a fix landed after the pinned Wine 11.16 baseline.
3. Copy the reviewed MacPorts Portfile into a local repository, add only the minimal upstream or reviewable patch, regenerate its checksums/index, and give the experimental port a distinct name such as `wine-storyline`.
4. Build the experimental port from source with `port -s`; pin the Wine commit and store the Portfile, patch, build flags, dependency versions, and hashes in this repository.
5. Rerun from a clean prefix—never declare success from a mutated debugging prefix.

Do not disable Gatekeeper or SIP to install a downloaded Wine build. Build through the pinned MacPorts recipe; keep any locally patched result classified as a research build until its source, inputs, and behavior have been reviewed.

Likely first source-level targets, in priority order, are Task Scheduler execution, Windows service lifecycle, WPF/DirectWrite, and host-browser callback delivery. Graphics translation becomes a target only after the desktop gate works and a Storyline render or media log identifies Direct3D as the boundary.

### 5C. Reporting upstream

If no fix exists, produce a minimal Wine bug report containing:

- MacPorts, Wine source commit/configuration, and macOS/Intel details
- smallest legal reproducer, when possible
- focused log beginning before the first failure
- exception code, missing API, and stack/module names
- confirmation that the same input hash was used in a clean prefix
- no account tokens, license data, personal paths, or proprietary Articulate binaries

The project can then track a concrete upstream dependency instead of periodically retrying unchanged prefixes.

## Logging discipline

Start with focused channels:

```bash
WINEDEBUG=+timestamp,+pid,+tid,+seh,+loaddll,+msi,+service wine target.exe 2> storyline-wine.log
```

Add only the channel implicated by the first failure. Do not begin with `+relay`; it produces enormous logs. Sanitize URLs, access tokens, email addresses, machine identifiers, and user paths before committing logs.

For every claimed fix, preserve:

- clean-prefix setup commands
- before/after logs
- the upstream issue or commit that justifies the change
- a prefix snapshot for local rollback
- acceptance results by Storyline build number

## Decision rules

| Outcome | Classification |
|---|---|
| Original EXE and complete Desktop gate pass | Continue to Storyline through the normal desktop workflow |
| Original EXE fails but official core MSI produces a fully working Desktop App | Valid bootstrapper workaround; continue to Storyline |
| Desktop UI opens but service, authentication, entitlement, or app management fails | Not working; continue only with a specific Wine-level lead |
| Desktop gate passes and Storyline installs but authoring/preview/publish fails | Experimental only; investigate the first failed feature |
| All three gates and an update pass from a clean scripted prefix | Working no-VM workaround |
| Required fix weakens licensing, TLS, code signing, Gatekeeper, or SIP | Reject the fix |
| Failure maps to an unimplemented API with no patch | Record upstream blocker; no working workaround yet |

## Recommended execution order

1. Obtain the full official Articulate deployment package and Microsoft prerequisites.
2. Build MacPorts `wine-devel` 11.16 from source and run the untouched installer once in a clean direct Wine prefix with focused logging.
3. If it fails, use a second clean prefix to install prerequisites and the official core MSI separately; restore Windows 10 mode after `dotnet48`.
4. Run the .NET Framework 4.8 verification and the independent .NET 10 WPF probe.
5. Verify whether Articulate's scheduled task actually retains and runs its action; use the narrow macOS launch-hook experiment if Wine's known scheduler gaps are the only failure.
6. Fingerprint the authentication browser and bridge a custom URI only if the callback is demonstrably lost at the macOS/Wine boundary.
7. Do not touch the Storyline MSI until the Articulate Desktop App passes service, sign-in, entitlement, catalog, restart, and update checks.
8. Once the desktop gate passes, install Storyline and run the full acceptance suite.
9. Test a newer pinned upstream Wine commit only against a specific baseline failure.
10. Add a local MacPorts Wine patch only when the log identifies a narrow upstream-fixable boundary.
11. Package the prefix as a Mac `.app` only after clean-room reproduction and the update test pass.

This order keeps the research entirely on macOS, treats Articulate 360 Desktop as mandatory, and concentrates engineering effort on measured Wine failures rather than unrelated virtualization or game-porting tools.

## Sources to recheck before each new run

- [Articulate 360 deployment guide](https://cdn.articulate.com/assets/kb/360/deployment/articulate-360-deployment-guide.html)
- [CodeWeavers Articulate 360 compatibility entry](https://www.codeweavers.com/compatibility/crossover/articulate-360)
- [Winetricks releases and issues](https://github.com/Winetricks/winetricks)
- [Winetricks current source: .NET Framework 4.8 and .NET Desktop 10 verbs](https://github.com/Winetricks/winetricks/blob/master/src/winetricks)
- [Winetricks release `20260125`](https://github.com/Winetricks/winetricks/releases/tag/20260125)
- [MacPorts 2.12.6 release](https://github.com/macports/macports-base/releases/tag/v2.12.6)
- [MacPorts `wine-devel` source-build recipe](https://github.com/macports/macports-ports/blob/master/emulators/wine-devel/Portfile)
- [Wine source and issue tracker](https://gitlab.winehq.org/wine/wine)
- [Homebrew's disabled `wine-stable` cask](https://github.com/Homebrew/homebrew-cask/blob/HEAD/Casks/w/wine-stable.rb)
- [Wine Task Scheduler command source](https://github.com/wine-mirror/wine/blob/master/programs/schtasks/schtasks.c)
- [Wine registered-task implementation](https://github.com/wine-mirror/wine/blob/master/dlls/taskschd/regtask.c)
- [Wine task XML/action implementation](https://github.com/wine-mirror/wine/blob/master/dlls/taskschd/task.c)
- [Microsoft .NET 10 Windows installation notes](https://github.com/dotnet/core/blob/main/release-notes/10.0/install-windows.md)
- [Microsoft .NET 10 machine-readable release metadata](https://github.com/dotnet/core/blob/main/release-notes/10.0/releases.json)
- [Microsoft WPF repository and platform statement](https://github.com/dotnet/wpf)
- [Microsoft WPF samples](https://github.com/microsoft/WPF-Samples)
- [Microsoft documentation source for `EnableWindowsTargeting`](https://github.com/dotnet/docs/blob/main/docs/core/project-sdk/msbuild-props.md#enablewindowstargeting)
- [Microsoft WebView2 Wine compatibility request](https://github.com/MicrosoftEdge/WebView2Feedback/issues/3127)
- [Wine Mono WebView2 assertion and fix](https://github.com/wine-mono/mono/issues/2)
- [Fusion 360 Wine OAuth callback pattern](https://github.com/mxioi/fusion360-wine-linux)
- [Lightroom Wine clean-prefix and post-.NET setup pattern](https://github.com/6im0n/lightroom-classic-on-linux/blob/main/resources/scripts/wine/setup.sh)
- [GNOME msitools](https://github.com/GNOME/msitools)
