# Run 07 — Storyline 360 installed (patched Wine, real .NET 4.8, signed-in prefix)

Prefix: wine-dotnet48-noadmintask, launched through ~/Applications/Articulate 360.app on the patched Wine (Run 06).

## Desktop App → Install Storyline (Try 1)
- No forced self-update this time; app stayed signed in across relaunch.
- Desktop Service downloaded the Storyline bundle; **Installer Service started** (first time ever) and received
  `ExecuteAsync(Family=Storyline, Operation=Install, Mode=Quiet, X64)`.
- Failure: `Service copying file … to privileged directory` → `InvalidOperationException: Directory has unexpected ACL.`
  at `ProtectedDirectory.CreateNew()`. The service stages the installer in a directory with a specific NTFS DACL and verifies
  it; Wine's security-descriptor emulation does not round-trip it. App shows "Unable to install Storyline 360 x64".
  logs/patched-wine/installer-service-acl-failure.log

## Direct run of the downloaded official bundle (plan Phase 4 rule: orchestration fails → run the official installer)
- Bundle preserved: inputs/storyline-360-x64-bundle.exe, SHA-256 4af16f80…d24216 (412 MB). Unmodified.
- `wine storyline-360-x64-bundle.exe` under patched Wine, interactive UI, same prefix:
  - WPF managed BA loaded; Detect: NetFx48 Present, DESKTOPNETCORERUNTIME10_x64 absent.
  - VC++ x86 0x0 · VC++ x64 0x0 · **DesktopNetCoreRuntime1006Redist_x64 0x0** · ThumbnailHandler MSI 0x0 ·
    **Articulate.Storyline_x64.Package.msi 0x0** · `Apply complete, result: 0x0`
  logs/patched-wine/storyline-bundle-burn.log

## Gate 1 status: PASS
launch ✔ services ✔ authenticate ✔ entitlement ✔ catalog ✔ restart ✔ Storyline installed ✔ (update-survival still untested)

## Open item
Installer-Service ACL check. Options: (a) Wine: make the DACL set on a new directory read back identically
(dlls/ntdll/unix/file.c security descriptor storage); (b) keep using the official bundle directly for installs/updates.
