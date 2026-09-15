# Run 04 — Real .NET Framework 4.8 prefix → Desktop App runs → sign-in completes

- Date: 2026-09-15 00:06–00:31 local
- Prefix: prefixes/wine-dotnet48-noadmintask (built by tools/build-prefix-dotnet48.sh):
  wineboot → winetricks `dotnet48 corefonts` (removes Mono, installs MS ndp48 offline, hash-verified) → `win10` → DisableNonAdminInstalls=true
  Verified: CurrentBuildNumber 19045, NDP\v4\Full\Release 0x80eb1, no Mono.

## 04a — Original EXE in this prefix: bootstrapper degrades
- Burn: `Loading prerequisite bootstrapper application because managed host could not be loaded, error: 0x8007000e`
- Falls back to prereq BA, sees .NET present, plans nothing, exits 0. **No install.**
- So: WPF bootstrapper UI works under Wine Mono but NOT under real .NET 4.8 (native CLR hosting fails).

## 04b — Direct payload install (Phase 2)
- Payloads taken from prefix 2's Burn Package Cache (already verified by Burn); hashes in SHA256SUMS.
- vc_redist x86: 0, x64: 0.
- `msiexec /i Articulate.360.Package.msi /qn`: **1603**. First failing action: `CreateRegistryValuesAction` (DTF managed CA):
  `SFXCA: Failed to create app domain. Error code 0x8007000E`  — same native-host→CLR failure as Burn.
- Both CLRs run fine standalone (`csc.exe` 32/64-bit OK). mscoree.dll is the 4.0.31106 shim; mscoreei.dll is 4.8.3761.
- Root cause not yet fixed; it only affects native hosts (Burn, DTF custom actions), not managed EXEs.

## 04c — Layout without custom actions
- `msiexec /a Articulate.360.Package.msi TARGETDIR=C:\ArticulateAdminImage` (administrative install, no CAs): exit 0, 269 files.
- Copied `Articulate\360` into `C:\Program Files\`, imported the registry keys the real installer wrote in prefix 2
  (HKLM\Software\Articulate\360\*\Install Location, Common\Settings\CurrentUICulture, Classes\Articulate URL protocol).
- Snapshot: wine-dotnet48-noadmintask-01-core-laid-out.tgz

## 04d — Desktop App
- `Articulate 360 Desktop App.exe` **runs**. It spawns `Articulate 360 Desktop Service.exe` itself (no Windows service).
- RPC app↔service OK; LaunchDarkly feature flags fetched → outbound HTTPS/TLS OK.
- Sign In page shown. OIDC via `OidcCustomUrlSchemeListener`: browser opened on macOS, sign-in completed at id.articulate.com,
  redirect page tried `articulate://callback?Code=…&State=…` → macOS had no handler → listener timed out (3 min).
- App then fell back to `OidcLoopbackListener` (localhost redirect) → **SignedIn, SubscriptionState: Active**.
- Catalog rendered: Storyline/Studio/Replay/Peek with Install buttons; Training/Review/Rise with Launch. Avatar + identity shown.
- Wine err: lines are benign (ole stub-manager noise, kerberos absent, one GL framebuffer complaint, AsyncCausalityTracer).

## URL bridge (built, not yet exercised)
- tools/macos-url-bridge/bridge.applescript compiled to ~/Applications/Articulate360Bridge.app with CFBundleURLTypes `articulate`.
- Transport-only: rejects non-`articulate://` and quote/space-containing URLs, forwards untouched to the genuine
  `Articulate 360 Desktop App.exe "<url>"` in the pinned prefix — identical to the Windows registry command. Never logs the URL.
- Registered with LaunchServices (claim "Articulate 360 sign-in callback", bindings articulate:).

## Gate 1 status
launch ✔ · services running ✔ · authenticate ✔ · entitlement ✔ · catalog ✔ · Storyline install ▢ · restart/update survival ▢
