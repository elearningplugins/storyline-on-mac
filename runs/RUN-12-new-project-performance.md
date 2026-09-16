# Run 12 — New Project load time

## Measurements (warm File → New, Storyline log markers AbandonProjectJobs → ProjectReadyForBackgroundProcessing)
| Build | Wall | Storyline CPU | wineserver CPU |
|---|---|---|---|
| patches 0001–0006 | 20.9 s | 17.1 s (82%) | 3.3 s (16%) |
| + `DOTNET_EnableWriteXorExecute=0 DOTNET_TieredPGO=0` | 18.3 s | 17.8 s | 1.9 s | 
| + patches 0007 (RNG) and 0005 colour space | **13.7 s** | — | — |
Cold first project after launch: 42–50 s before → 15.1 s after (cold numbers vary with disk cache).

## Profile of a warm New Project (sample, active samples only, PE modules attributed via +loaddll addresses)
coreclr 26% · clrjit 24% · JIT'd managed code 19% · vImage/CoreGraphics colour conversion 7% · memmove 4% ·
ntdll.so file lookups/xattr 4% · `__open` (RNG via /dev/urandom) 3% · other 13%.
→ ~70% is the .NET runtime compiling/running Articulate's code. All 180 managed assemblies ship IL-only (no ReadyToRun),
so every project open JITs; that is Storyline's design and happens on Windows too. Wine's share was ~15–20%.

## Wine-side fixes
- 0007 ntdll (unix): `get_random` uses `arc4random_buf` on macOS instead of open/read/close of /dev/urandom per call
  (.NET calls it for hash seeds and GUIDs constantly).
- 0005 winemac (extended): surface images tagged with the main display's colour space (cached `NSScreen.colorSpace`) so
  CoreGraphics blits instead of converting 8→16-bit planar with a soft mask every frame.
- Not done on purpose: ReadyToRun-compiling Articulate's assemblies would remove most of the JIT cost but modifies vendor
  binaries (out of scope under the plan).
- `DOTNET_EnableWriteXorExecute=0` made no measurable difference; not kept.
