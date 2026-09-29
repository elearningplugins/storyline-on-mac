# Run 21 — Image decoding: ~97 registry round trips per icon

## Symptom
A CPU trace of a cold launch (Run 20) puts about 2.9 s of main-thread time in `Articulate.Resources.GDICache.GetImage` → `System.Drawing.Image.FromStream`, while ribbon commands load their icons. `GetImage` is a plain `Image.FromStream` on an embedded resource, so the time is inside Wine's GDI+ and WIC.

## Measuring it outside Storyline
A local probe (`~/StorylineLab/tools/iconprobe`, not in the repo) loads every embedded image in the installed `Articulate*.dll` files (1,727 images, 1,710 of them PNG) and decodes each with `Image.FromStream`, as `GDICache` does. On stock Wine, PNGs took **1.88 ms each** (3.2 s per pass), including 16×16 icons.

A macOS `sample` of the decode loop was dominated by `NtEnumerateKey`, `NtOpenKeyEx`, `NtQueryValueKey` and `NtClose`, each a wineserver round trip. A `WINEDEBUG=trace+reg` log of 20 decodes, bracketed with markers, counted per image:
- ~47 `RegEnumKeyExW`, ~20 `NtOpenKeyEx`, ~10 value reads;
- one enumeration of `CATID_WICBitmapDecoders` and ~2.25 of `CATID_WICMetadataReader`;
- 8 reads of `ContainerFormat` (the PNG decoder is 8th) and ~2 of `MetadataFormat`.

## Cause
In `dlls/windowscodecs/info.c`:
- `CreateComponentEnumerator` opens `HKCR\CLSID\{category}\Instance` and enumerates its subkeys on every call. `ImagingFactory_CreateDecoder` (from GDI+'s `initialize_decoder_wic`) and the metadata reader lookup call it for every image.
- `ComponentInfo_GetGUIDValue` reads `ContainerFormat` / `MetadataFormat` / `Vendor` from the registry every time, although the component info objects themselves are already cached for the life of the process (`component_info_cache`).

## Fix: patch 0017
`tools/wine-patches/0017-windowscodecs-cache-component-lists-and-GUID-values.patch`:
- `ComponentInfo` keeps the three GUID values once read (`ReadAcquire` / `WriteRelease`, since info objects are shared between threads).
- `CreateComponentEnumerator` takes each category's CLSID list from a cache. The cache holds the `Instance` key open with `RegNotifyChangeKeyValue(REG_NOTIFY_CHANGE_NAME)` and re-reads the list once that fires, so components registered or removed while the process runs are still seen. The notification is registered before reading, so a change made during the read also invalidates it. If the key can't be opened or watched, the list is read every time, as before.
- Error behavior is unchanged: a missing category key or a failing `RegEnumKeyExW` still fails the enumeration.

`build-ntdll.sh` builds 64- and 32-bit `windowscodecs.dll` and copies them into the mirror. Storyline loads it from the mirror (checked with `vmmap`), not the prefix's `system32` copy.

## Verified
- **Registry traffic:** registry calls inside the probe's decode loop went from ~97 per image to 0.1.
- **Probe, quiet machine:** PNG average 1.88 → 0.93–1.15 ms. By size: ≤48×48 (1,492 images) 0.25–0.28 ms each; ≤256×256 (153) 0.64–0.70 ms; larger (82, mostly 1024×768 quiz thumbnails) ~10.5 ms, which is real decoding work in windowscodecs.
- **Probe, alternating stock and patched under load (load average 9–20):** full pass 8.0–8.9 s → 2.2–2.7 s; ≤48×48 icons 3.9–4.3 ms → 0.45–0.68 ms each.
- **Storyline cold launches, alternating stock and patched, 3 pairs (load average 9–19):** process → start screen 64.1 → 58.9 s, 65.6 → 50.4 s, 43.7 → 37.4 s. Patched was faster every time; the load makes the size of the gain unreliable.
- **Wine conformance tests** (`dlls/windowscodecs/tests`, 15 modules, built with MinGW + `winegcc` because the build uses `--disable-tests`, run in a throwaway prefix): stock and patched both 38,705 tests, 0 failures, identical todo and skip counts.
- **Runtime registration** (`~/StorylineLab/tools/wicregprobe`): counting decoders, registering a copy of the PNG decoder under a new CLSID, counting again, removing it and counting again gives 8, 9, 8 on both stock and patched.
- **Storyline:** the ribbon and panel icons render as before (New Project, slide view).
- The patch applies to the pristine source and gives a file identical to the one built, reverse-applies, and `info.c` compiles with no warnings. The build step, run on its own, produced a DLL that differs from the tested one only in the PE timestamp and checksum (4 bytes).

## Not verified
- Apps that change WIC registrations through a path other than the `Instance` key's subkey names (for example, editing a registered component's values in place) would see the old `ContainerFormat` / `MetadataFormat` / `Vendor` until restart. Wine's existing `component_info_cache` already makes the same assumption about the rest of a component's registration.
- WPF image decoding, which also goes through WIC, was not measured separately.
