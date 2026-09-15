# Run 01 — Phase 1 baseline: original EXE in clean Wine 11.16 prefix

- Date: 2026-09-14 23:54 local
- macOS 15.7.9 (24G830), Intel x86_64, MacBookPro15,4
- CLT reinstalled before Wine install (clang-1700.0.13.5); see ../macports/clt-reinstall.txt
- MacPorts 2.12.6 (pkg SHA-256 verified vs GitHub asset digest; Developer ID + notarized)
- wine-devel @11.16_0+ffmpeg+gstreamer (binary archive, not source), Wine Mono 11.3.0, Gecko 2.47.4
- Prefix: prefixes/wine-burn-clean, WINEARCH=win64, Windows 10 Pro build 19045 (verified via reg query)
- Input: articulate-360.exe SHA-256 bc725a70…c88e9 (Burn 3.11.2, bundle 1.125.37980.0)
- WINEDEBUG=+timestamp,+pid,+tid,+seh,+loaddll,+msi,+service
- Logs: 20260914-235414.log (Wine), Articulate_360_20260914235417.log (Burn), *_002_Articulate.360.Package.msi.log (MSI)
- Snapshots: wine-burn-clean-00-fresh.tgz, wine-burn-clean-01-after-burn-fail.tgz

## Result
- Burn painted: YES. Managed WPF bootstrapper (Articulate.Bootstrapper.Application.dll / Prism) runs under Wine Mono, UI renders correctly.
- NETFRAMEWORK45 detected as 533320 (Wine Mono shim, not real .NET 4.8).
- vc_redist x86: 0x0. vc_redist x64: 0x0.
- Articulate.360.Package.msi: 0x80070643, rolled back.

## First failing action
MSI custom action `RegisterScheduledTaskAction` (Articulate.CustomActions.dll, DTF/SFXCA, CLR v4.0.30319):
  System.NotImplementedException at Microsoft.Win32.TaskScheduler.V2Interop.ITaskSettings.get_IdleSettings()
Wine side: `fixme:taskschd:TaskSettings_get_IdleSettings … : stub` (dlls/taskschd/task.c returns E_NOTIMPL).
All prior actions (InstallFiles, WriteRegistryValues, service tables, CreateRegistryValuesAction) returned 1.

## Classification
"Core MSI custom action fails" → inspect action. Action is nonessential to core install: it only registers the
non-admin update task, and reads HKLM\Software\Articulate\Common\Settings\DisableNonAdminInstalls first —
if True it skips task creation.

## Candidate next steps
A. Pre-set DisableNonAdminInstalls in a fresh prefix and rerun the EXE (plan-permitted "pre-create registry value").
B. Wine patch: implement ITaskSettings::get_IdleSettings (return an IIdleSettings stub) — Phase 5B.
