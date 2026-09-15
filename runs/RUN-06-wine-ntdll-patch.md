# Run 06 — Research build of ntdll.so with the WoW64 allocation clamp (in progress)

Patch: tools/wine-patches/0001-ntdll-clamp-wow64-allocations-to-highest-user-address.patch
Build: tools/wine-build/build-ntdll.sh (only `dlls/ntdll/ntdll.so`; /opt/local untouched; run from ~/StorylineLab/wine-patched/bin/wine)

## Findings so far
1. Source: wine-11.16 tarball, SHA-256 matches the MacPorts Portfile. MacPorts' only patch is an unrelated win32u Vulkan change.
2. Wine 10+ needs a PE cross-compiler even to configure → `port install mingw-w64 bison flex` (bison 2.3 in macOS is too old).
3. Mirror pitfall: `lib/wine/x86_64-unix/wine` is the real loader and Wine re-execs it; if it is a symlink into /opt/local, every
   process after the first loads the stock ntdll.so. It must be a copy inside the mirror. (Verified with DYLD_PRINT_LIBRARIES.)
4. **First build (default macOS 15 deployment target) segfaults `msiexec` at startup** — `cmd` runs, `msiexec` dies before the first
   WoW64 call, with or without the clamp. Mirror + stock ntdll.so is fine, so it is the build, not the layout.
   MacPorts' Portfile sets `macosx_deployment_target 14.0` on macOS 15 with a link to a Wine MR note about exactly this.
   Rebuild with `MACOSX_DEPLOYMENT_TARGET=14.0` / `-mmacosx-version-min=14.0` started but did not complete (see 5).
5. Session ended blocked by macOS: after an `lldb --batch` attempt to catch the segfault, newly launched executables (even a
   fresh hello-world) and some file reads (~/Library/Logs/DiagnosticReports) enter uninterruptible wait (`U`) — Gatekeeper /
   privacy prompt pending on screen or a wedged assessment daemon. Not recoverable headlessly; dismiss the dialog or reboot.

## Next (after reboot)
- `tools/wine-build/build-ntdll.sh` (≈3 min) → verify `~/StorylineLab/wine-patched/bin/wine msiexec /qn /i C:\nonexistent.msi` exits 2, not 139.
- `WINEPREFIX=…/wine-dotnet48-noadmintask ~/StorylineLab/wine-patched/bin/wine msiexec /i Articulate.360.Package.msi /qn /L*v C:\x.log`
  → expect `CreateRegistryValuesAction` / `RegisterScheduledTaskAction` to run (no `SFXCA: Failed to create app domain`).
- Then the original `articulate-360.exe` under patched Wine (expect the WPF bootstrapper to load under real .NET), then the
  Desktop App self-update, then Storyline. Switch the launcher's `Contents/lib` symlink to the mirror when it proves out.
- Remove the temporary `wowclamp` TRACE line before proposing upstream.

## Result (continued after the hang cleared on its own)
- The `msiexec` segfault was NOT the deployment target: the lib mirror lacked `share/wine/nls`, so ntdll's case tables were
  NULL and `towupper` crashed inside `find_env_var` (macOS crash report). Fixed by `ln -s /opt/local/share $M/share`
  (build-ntdll.sh updated). The 14.0 target is kept anyway to match MacPorts.
- **Core MSI direct install with the clamp: exit 0.** Both DTF custom actions hosted the CLR and ran
  (`CreateRegistryValuesAction`, `RegisterScheduledTaskAction`). Trace: 109 allocations had limit_high=0x7fffffff clamped to
  0x7fff0000; zero allocations at 0x7fff0000. logs/patched-wine/core-msi-direct.log, clamp-summary.txt
- **Original `articulate-360.exe` (/passive) in a fresh real-.NET-4.8 prefix under the patched Wine: full success.**
  `Loading managed bootstrapper application` → VC++ x86 0x0 → VC++ x64 0x0 → core MSI 0x0 → `Apply complete, result: 0x0`.
  logs/patched-wine/burn-original-exe.log
- Conclusion: one ~8-line ntdll fix turns "Will Not Install" into "installs with the vendor's own bootstrapper".
  Upstream candidate: dlls/ntdll/unix/virtual.c (clamp WoW64 limit_high) — remove the TRACE line first.
