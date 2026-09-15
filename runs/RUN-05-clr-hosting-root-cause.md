# Run 05 — Root cause of 0x8007000E (native CLR hosting fails in 32-bit processes)

Affects: WiX Burn managed BA (`mbahost`), DTF `SFXCA` custom actions → Articulate installer UI, Desktop App self-update,
every DTF custom action in Articulate MSIs (core: `CreateRegistryValuesAction`, `RegisterScheduledTaskAction`).

## Reproduction
`wine msiexec /i Articulate.360.Package.msi /qn` in prefix wine-dotnet48-noadmintask with
`WINEDEBUG=+seh,+loaddll,+module,+virtual,+msi` (logs/clrhost-trace/).
The CA runs in Wine's 32-bit CA server `syswow64\rundll32.exe` (pid 0338). 32-bit `mscoree` → `mscoreei` (4.8.3761)
→ `clr.dll` → `mscorlib.ni.dll` all load. Then the CLR throws a managed exception `e0434352` with info[0]=`8007000E`
(OutOfMemoryException) during AppDomain creation.

## What happened just before the exception (CA host)
CLR top-down allocations (`MEM_COMMIT|MEM_RESERVE|MEM_TOP_DOWN`, PAGE_EXECUTE_READWRITE):
```
0x7ff60000-0x7ffe0000   (rw, earlier)
0x7ff10000-0x7ff60000   (rwx)
0x7fff0000-0x80000000   (rwx)   <-- above the KUSER_SHARED_DATA page, last 64 KB below 2 GB
NtFreeVirtualMemory 0x7fff0000 ; NtFreeVirtualMemory 0x7ff10000 ; → OutOfMemoryException
```
Control: 32-bit `csc.exe` (works) gets its top-down blocks at `0x7ff60000-0x7ffe0000` only and never touches 0x7fff0000.

On Windows a non-LAA 32-bit process has HighestUserAddress = 0x7FFEFFFF; `0x7FFF0000-0x7FFFFFFF` is never allocatable.
The CLR's executable-memory allocator validates results against `lpMaximumApplicationAddress`, rejects the block, and after
its retries gives up with E_OUTOFMEMORY. `rundll32.exe` (Wine builtin) is not large-address-aware (checked PE flags), so the
process limit should be 0x7fff0000.

## Where Wine gets it wrong (wine-11.16)
- `dlls/wow64/syscall.c:998`  `default_zero_bits = (ULONG_PTR)info.HighestUserAddress | 0x7fffffff;`
  → for HighestUserAddress 0x7ffeffff this becomes 0x7fffffff (zero_bits masks must be 2^n-1).
- `dlls/wow64/virtual.c:163`  passes that as zero_bits for every plain NtAllocateVirtualMemory from 32-bit code.
- `dlls/ntdll/unix/virtual.c` `NtAllocateVirtualMemory` → `get_zero_bits_limit()` → limit_high 0x7fffffff →
  `map_view`: `end = limit_high + 1` = 0x80000000. The precise WoW limit `get_wow_user_space_limit()` (0x7fff0000)
  is only applied in the image-mapping path (virtual.c:3382), not for ordinary allocations.

## Tried and rejected
- `WINEPRELOADRESERVE=0x7fff0000-0x80000000`: not honoured on this macOS build (allocation still landed there).

## Fix candidates
A. ntdll (unix): in `allocate_virtual_memory`/`map_view` for wow64 processes clamp `limit_high` to
   `get_wow_user_space_limit() - 1` when it is 0 or larger. Small, matches Windows semantics, fixes all 32-bit callers.
B. wow64: compute `default_zero_bits` so the limit is the real HighestUserAddress — not expressible as a 2^n-1 mask, so A.

Next: build a research `ntdll.so` from wine-11.16 with fix A, run it from a private lib mirror (no change to /opt/local),
re-run the core MSI, then Burn, then the self-update.
