# Run 02 — Original EXE with DisableNonAdminInstalls=true (fresh prefix)

- Date: 2026-09-15 00:00 local
- Same host/Wine/input as Run 01
- Prefix: prefixes/wine-burn-noadmintask, WINEARCH=win64, Windows 10 build 19045
- Pre-set before running installer: `HKLM\Software\Articulate\Common\Settings\DisableNonAdminInstalls` REG_SZ `true`
  (documented Articulate enterprise setting; see deployment guide)
- Logs: logs/burn-noadmintask/

## Result
- vc_redist x86: 0x0, vc_redist x64: 0x0
- **Articulate.360.Package.msi: 0x0** — Apply complete 0x0.
- RegisterScheduledTaskAction logged "disable non-admin installs = True → Removing the scheduled task", Return value 1.
- Installed: `Desktop Application x64\{Articulate 360 Desktop App.exe, Articulate 360 Installer Service.exe}`,
  `Desktop Service x64\Articulate 360 Desktop Service.exe`, HKLM\Software\Articulate\360\* keys.
- No entries under HKLM\System\CurrentControlSet\Services (desktop service may not be a Windows service).
- Snapshot: wine-burn-noadmintask-01-core-installed.tgz

## Classification
Original EXE + one documented registry value = core install passes. Bootstrapper bypass (direct MSI) not needed.

# Run 03 — Launch Articulate 360 Desktop App.exe (same prefix)

- Logs: logs/desktop-app/
- Exit code 1 after ~6 s. No Wine err:. App's own Serilog log captured the cause:

```
Autofac DependencyResolutionException → SerilogTraceListener → Serilog.Core.Logger
  → System.TypeLoadException: Could not resolve type … expected class
    'System.Diagnostics.Eventing.Reader.EventLogInvalidDataException' in assembly 'System.Core, Version=4.0.0.0'
```

## Classification
Wine Mono's System.Core lacks the type; real .NET Framework 4.8 has it. Not a Wine API gap.
Next: Run 04 — fresh prefix with winetricks `dotnet48` (Mono removed), `win10` reset, same registry value, same EXE.
