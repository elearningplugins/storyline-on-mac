#!/bin/bash
# Rebuild only ntdll.so from the pinned wine-11.16 source with the wow64 clamp patch, matching MacPorts' build settings.
# Prereqs (MacPorts): wine-devel 11.16, mingw-w64, bison, flex. Nothing here touches /opt/local.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LAB="$HOME/StorylineLab"; SRC="$LAB/wine-src"; B="$SRC/build"
[ -f "$SRC/wine-11.16.tar.gz" ] || curl -sL -o "$SRC/wine-11.16.tar.gz" https://github.com/wine-mirror/wine/archive/refs/tags/wine-11.16.tar.gz
echo "2b6d5cff784cb774f7f17b9a640b123ca8361d89c4280c0021b70bb6f3cd1b1c  $SRC/wine-11.16.tar.gz" | shasum -a 256 -c
[ -d "$SRC/wine-wine-11.16" ] || tar -xzf "$SRC/wine-11.16.tar.gz" -C "$SRC"
cd "$SRC/wine-wine-11.16" && git apply --check "$(dirname "$0")/../wine-patches/0001-ntdll-clamp-wow64-allocations-to-highest-user-address.patch" 2>/dev/null \
  && git apply "$(dirname "$0")/../wine-patches/0001-ntdll-clamp-wow64-allocations-to-highest-user-address.patch" || echo "patch already applied"
rm -rf "$B"; mkdir -p "$B"; cd "$B"
# MacPorts builds wine-devel with macosx_deployment_target 14.0 on macOS 15 (see its Portfile); a 15.x target crashes msiexec.
export MACOSX_DEPLOYMENT_TARGET=14.0 PATH="/opt/local/bin:$PATH"
CC="clang -mmacosx-version-min=14.0" CFLAGS="-O2" CPPFLAGS="-I/opt/local/include" LDFLAGS="-L/opt/local/lib -Wl,-rpath,/opt/local/lib" \
PKG_CONFIG_PATH=/opt/local/lib/pkgconfig CROSSCFLAGS="-O2" \
../wine-wine-11.16/configure --prefix=/opt/local --enable-archs=i386,x86_64 --enable-win64 --disable-tests --disable-winebth_sys \
  --without-alsa --without-capi --with-coreaudio --with-cups --without-dbus --without-ffmpeg --without-fontconfig --with-freetype \
  --with-gettext --without-gettextpo --without-gphoto --with-gnutls --without-gssapi --without-gstreamer --without-inotify --without-krb5 \
  --with-mingw --without-netapi --with-opencl --without-opengl --without-oss --with-pcap --with-pcsclite --with-pthread --without-pulse \
  --without-sane --with-sdl --without-udev --without-usb --without-v4l2 --with-vulkan --without-wayland --without-x > configure.log 2>&1
make -j4 dlls/ntdll/ntdll.so > make-ntdll.log 2>&1
# private mirror of /opt/local/lib/wine with only ntdll.so replaced; the loader is copied (not linked) so re-exec stays in the mirror
M="$LAB/wine-patched"; rm -rf "$M"; mkdir -p "$M/lib/wine" "$M/bin"
for d in /opt/local/lib/wine/*; do n=$(basename "$d"); mkdir -p "$M/lib/wine/$n"; for f in "$d"/*; do ln -s "$f" "$M/lib/wine/$n/$(basename "$f")"; done; done
rm "$M/lib/wine/x86_64-unix/ntdll.so" "$M/lib/wine/x86_64-unix/wine"
cp "$B/dlls/ntdll/ntdll.so" "$M/lib/wine/x86_64-unix/ntdll.so"; cp /opt/local/lib/wine/x86_64-unix/wine "$M/lib/wine/x86_64-unix/wine"
cp /opt/local/bin/wine "$M/bin/wine"; ln -sf /opt/local/bin/wineserver "$M/bin/wineserver"; ln -sfn /opt/local/share "$M/share"
echo "patched wine at $M/bin/wine"; "$M/bin/wine" --version
# --- dwrite (PE) : IDWriteTextAnalyzer1 justification methods (patch 0002) ---
cd "$SRC/wine-wine-11.16" && { git apply --check "$(dirname "$0")/../wine-patches/0002-dwrite-implement-IDWriteTextAnalyzer1-justification.patch" 2>/dev/null \
  && git apply "$(dirname "$0")/../wine-patches/0002-dwrite-implement-IDWriteTextAnalyzer1-justification.patch" || echo "dwrite patch already applied"; }
# (patch 0026: WINE_DWRITE_NBSP_NOT_WHITESPACE=1 stops reporting no-break spaces as white space, because Storyline breaks lines at every white space character; issue #20)
P26="$(dirname "$0")/../wine-patches/0026-dwrite-opt-in-no-break-spaces-are-not-white-space.patch"
cd "$SRC/wine-wine-11.16" && { git apply --check "$P26" 2>/dev/null && git apply "$P26" || echo "dwrite patch 0026 already applied"; }
cd "$B" && make -j4 dlls/dwrite/x86_64-windows/dwrite.dll > make-dwrite.log 2>&1
rm -f "$M/lib/wine/x86_64-windows/dwrite.dll"; cp "$B/dlls/dwrite/x86_64-windows/dwrite.dll" "$M/lib/wine/x86_64-windows/dwrite.dll"
echo "patched dwrite.dll in $M (also copy it over <prefix>/drive_c/windows/system32/dwrite.dll)"
# --- wined3d (PE) : relaxed Vulkan feature-level gate for MoltenVK (patch 0003; enabled by WINE_D3D_FL_RELAX=1) ---
cd "$SRC/wine-wine-11.16" && { git apply --check "$(dirname "$0")/../wine-patches/0003-wined3d-vk-relax-feature-level-gate-for-moltenvk.patch" 2>/dev/null \
  && git apply "$(dirname "$0")/../wine-patches/0003-wined3d-vk-relax-feature-level-gate-for-moltenvk.patch" || echo "wined3d patch already applied"; }
cd "$B" && make -j4 dlls/wined3d/x86_64-windows/wined3d.dll > make-wined3d.log 2>&1
rm -f "$M/lib/wine/x86_64-windows/wined3d.dll"; cp "$B/dlls/wined3d/x86_64-windows/wined3d.dll" "$M/lib/wine/x86_64-windows/wined3d.dll"
echo "patched wined3d.dll in $M (also copy it over <prefix>/drive_c/windows/system32/wined3d.dll)"
# --- d2d1 (PE) : pass the stroke transform across the VS/PS interface as float4 (patch 0004; SPIR-V backend rejects the float2x2 packing) ---
cd "$SRC/wine-wine-11.16" && { git apply --check "$(dirname "$0")/../wine-patches/0004-d2d1-pass-stroke-transform-as-float4-for-spirv.patch" 2>/dev/null \
  && git apply "$(dirname "$0")/../wine-patches/0004-d2d1-pass-stroke-transform-as-float4-for-spirv.patch" || echo "d2d1 patch already applied"; }
# (patch 0008: DrawImage honours D2D1_COMPOSITE_MODE_MASK_INVERT, which Storyline uses to draw the text caret)
P8="$HERE/../wine-patches/0008-d2d1-implement-mask-invert-composite-mode.patch"; cd "$SRC/wine-wine-11.16"
if git apply --check "$P8" 2>/dev/null; then git apply "$P8"
elif git apply --reverse --check "$P8" 2>/dev/null; then echo "d2d1 mask-invert patch already applied"
else echo "patch 0008 neither applies nor is already applied; source tree is not pinned wine-11.16 + 0004" >&2; exit 1; fi
cd "$B" && make -j4 dlls/d2d1/x86_64-windows/d2d1.dll > make-d2d1.log 2>&1
rm -f "$M/lib/wine/x86_64-windows/d2d1.dll"; cp "$B/dlls/d2d1/x86_64-windows/d2d1.dll" "$M/lib/wine/x86_64-windows/d2d1.dll"
echo "patched d2d1.dll in $M (also copy it over <prefix>/drive_c/windows/system32/d2d1.dll)"
# (patch 0007: ntdll get_random via arc4random_buf — applied with the winemac step below)
cd "$SRC/wine-wine-11.16" && { git apply --check "$(dirname "$0")/../wine-patches/0007-ntdll-macos-arc4random-for-get_random.patch" 2>/dev/null && git apply "$(dirname "$0")/../wine-patches/0007-ntdll-macos-arc4random-for-get_random.patch" || echo "rng patch already applied"; }
# (patch 0011: WINE_PERF_LOG per-second file lookup totals by thread and folder — also built with the winemac step)
P11="$HERE/../wine-patches/0011-ntdll-perf-log-file-lookups.patch"
cd "$SRC/wine-wine-11.16" && if git apply --check "$P11" 2>/dev/null; then git apply "$P11"; elif git apply --check -R "$P11" 2>/dev/null; then echo "file-lookup logging patch already applied"; else echo "patch 0011 does not apply"; exit 1; fi
# --- winemac.drv (unix) : no per-frame shadow recompute for per-pixel-alpha windows (patch 0005) ---
cd "$SRC/wine-wine-11.16" && { git apply --check "$(dirname "$0")/../wine-patches/0005-winemac-no-shadow-recompute-for-per-pixel-alpha-windows.patch" 2>/dev/null \
  && git apply "$(dirname "$0")/../wine-patches/0005-winemac-no-shadow-recompute-for-per-pixel-alpha-windows.patch" || echo "winemac patch already applied"; }
# (patch 0010: menu bar and Dock name from WINE_MAC_APP_NAMES instead of "wine")
P10="$HERE/../wine-patches/0010-winemac-name-app-after-windows-exe.patch"
cd "$SRC/wine-wine-11.16" && if git apply --check "$P10" 2>/dev/null; then git apply "$P10"; elif git apply --check -R "$P10" 2>/dev/null; then echo "winemac app-name patch already applied"; else echo "patch 0010 does not apply"; exit 1; fi
# (patch 0016: the Windows wait and app-starting cursors show AppKit's busy cursor instead of the Windows hourglass)
P16="$HERE/../wine-patches/0016-winemac-show-the-AppKit-busy-cursor-for-the-wait-cursors.patch"
cd "$SRC/wine-wine-11.16" && if git apply --check "$P16" 2>/dev/null; then git apply "$P16"; elif git apply --check -R "$P16" 2>/dev/null; then echo "winemac busy-cursor patch already applied"; else echo "patch 0016 does not apply"; exit 1; fi
# (patch 0029: a process that finds the initial display mode key waits until its creator has finished writing it; reading it half-written turned Retina mode off for that process, e.g. Storyline opening at 720x407 when started alongside the Desktop Service)
P29="$HERE/../wine-patches/0029-winemac-wait-for-the-initial-display-mode-to-be-written.patch"
cd "$SRC/wine-wine-11.16" && if git apply --check "$P29" 2>/dev/null; then git apply "$P29"; elif git apply --check -R "$P29" 2>/dev/null; then echo "initial display mode patch already applied"; else echo "patch 0029 does not apply"; exit 1; fi
cd "$B" && make -j4 dlls/winemac.drv/winemac.so dlls/ntdll/ntdll.so > make-winemac.log 2>&1; cp "$B/dlls/ntdll/ntdll.so" "$M/lib/wine/x86_64-unix/ntdll.so"
rm -f "$M/lib/wine/x86_64-unix/winemac.so"; cp "$B/dlls/winemac.drv/winemac.so" "$M/lib/wine/x86_64-unix/winemac.so"
echo "patched winemac.so in $M"
# --- win32u (unix) : UpdateLayeredWindow copy fast path (patch 0006); the code lives in win32u.so, not win32u.dll ---
cd "$SRC/wine-wine-11.16" && { git apply --check "$(dirname "$0")/../wine-patches/0006-win32u-UpdateLayeredWindow-copy-fast-path.patch" 2>/dev/null \
  && git apply "$(dirname "$0")/../wine-patches/0006-win32u-UpdateLayeredWindow-copy-fast-path.patch" || echo "win32u patch already applied"; }
# MacPorts' one wine-devel patch (win32u Vulkan portability enumeration); a win32u.so built without it cannot see MoltenVK
PU="$HERE/../wine-patches/upstream/macports-0001-win32u-Enable-host-Vulkan-portability-enumeration.diff"; cd "$SRC/wine-wine-11.16"
if patch -p1 -N -s --dry-run < "$PU" >/dev/null 2>&1; then patch -p1 -N -s < "$PU"
elif patch -p1 -R -s --dry-run < "$PU" >/dev/null 2>&1; then echo "MacPorts Vulkan portability patch already applied"
else echo "MacPorts Vulkan portability patch neither applies nor is already applied" >&2; exit 1; fi
# (patch 0022: GDI_ROUND saturates instead of wrapping, so WinForms' unbounded text rectangles survive a viewport offset; the trigger list's "–" marks need it)
P22="$HERE/../wine-patches/0022-win32u-saturate-GDI_ROUND-instead-of-wrapping.patch"
if git apply --check "$P22" 2>/dev/null; then git apply "$P22"
elif git apply --reverse --check "$P22" 2>/dev/null; then echo "GDI_ROUND saturation patch already applied"
else echo "patch 0022 neither applies nor is already applied" >&2; exit 1; fi
# (patch 0025: no default IME window for children of message-only windows, as on Windows; each WinForms text pane parked there otherwise creates and destroys a Cocoa window, about 12 s of a 70 s publish in Run 28)
P25="$HERE/../wine-patches/0025-win32u-no-default-IME-window-for-descendants-of-message-only-windows.patch"
if git apply --check "$P25" 2>/dev/null; then git apply "$P25"
elif git apply --reverse --check "$P25" 2>/dev/null; then echo "message-only IME window patch already applied"
else echo "patch 0025 neither applies nor is already applied" >&2; exit 1; fi
# (patch 0009: WINE_PERF_LOG=1 timing lines from d2d1 and win32u for tools/perf/; silent otherwise)
P9="$HERE/../wine-patches/0009-perf-log-instrumentation.patch"
if git apply --check "$P9" 2>/dev/null; then git apply "$P9"
elif git apply --reverse --check "$P9" 2>/dev/null; then echo "perf instrumentation patch already applied"
else echo "patch 0009 neither applies nor is already applied; it needs 0004, 0006 and 0008 first" >&2; exit 1; fi
# (patch 0020: WINE_SCALE_FILTER=xbr enlarges DPI-unaware windows with xBR instead of halftone, which the Retina launchers set)
P20="$HERE/../wine-patches/0020-win32u-xbr-filter-for-scaled-dpi-unaware-windows.patch"
if git apply --check "$P20" 2>/dev/null; then git apply "$P20"
elif git apply --reverse --check "$P20" 2>/dev/null; then echo "scale filter patch already applied"
else echo "patch 0020 neither applies nor is already applied" >&2; exit 1; fi
cd "$B" && make -j4 dlls/win32u/win32u.so dlls/win32u/x86_64-windows/win32u.dll dlls/d2d1/x86_64-windows/d2d1.dll > make-win32u.log 2>&1
rm -f "$M/lib/wine/x86_64-unix/win32u.so"; cp "$B/dlls/win32u/win32u.so" "$M/lib/wine/x86_64-unix/win32u.so"
rm -f "$M/lib/wine/x86_64-windows/win32u.dll"; cp "$B/dlls/win32u/x86_64-windows/win32u.dll" "$M/lib/wine/x86_64-windows/win32u.dll"
rm -f "$M/lib/wine/x86_64-windows/d2d1.dll"; cp "$B/dlls/d2d1/x86_64-windows/d2d1.dll" "$M/lib/wine/x86_64-windows/d2d1.dll"
echo "patched win32u.so (with 0009, 0020), win32u.dll and d2d1.dll (with 0009) in $M"
# --- kernelbase (PE) : GetLocaleInfoEx answers LOCALE_SNAME for unknown well-formed names like Windows 10 (patch 0012); without it Storyline reloads its player on every click ---
P12="$HERE/../wine-patches/0012-kernelbase-answer-LOCALE_SNAME-for-unknown-well-formed-locale-names.patch"; cd "$SRC/wine-wine-11.16"
if git apply --check "$P12" 2>/dev/null; then git apply "$P12"
elif git apply --reverse --check "$P12" 2>/dev/null; then echo "locale name patch already applied"
else echo "patch 0012 neither applies nor is already applied" >&2; exit 1; fi
# CreateProcess appends the WINE_APPEND_ARGS switches (patch 0018), so Storyline started by the Desktop App gets the launcher's CEF flags.
P18="$HERE/../wine-patches/0018-kernelbase-append-configured-arguments-to-new-processes.patch"
if git apply --check "$P18" 2>/dev/null; then git apply "$P18"
elif git apply --reverse --check "$P18" 2>/dev/null; then echo "append-arguments patch already applied"
else echo "patch 0018 neither applies nor is already applied" >&2; exit 1; fi
cd "$B" && make -j4 dlls/kernelbase/x86_64-windows/kernelbase.dll dlls/kernelbase/i386-windows/kernelbase.dll > make-kernelbase.log 2>&1
for a in x86_64 i386; do rm -f "$M/lib/wine/$a-windows/kernelbase.dll"; cp "$B/dlls/kernelbase/$a-windows/kernelbase.dll" "$M/lib/wine/$a-windows/kernelbase.dll"; done
echo "patched kernelbase.dll (0012, 0018; 64- and 32-bit) in $M"
# --- gdiplus (PE) : path gradients honour preset blends (0013, Story View's scene-card shadow corners), CloseAllFigures closes the last figure (0014, outlines of Storyline's pill buttons), the world transform is relative to BeginContainer (0021, trigger list lines), metafiles get real frame bounds and play back in device space (0023, radio buttons and checkboxes on the slide canvas) and closed outlines lose their rounding-error closing point (0024, notch in every circle outline) ---
cd "$SRC/wine-wine-11.16"
for P in "$HERE/../wine-patches/0013-gdiplus-implement-path-gradient-preset-blend.patch" "$HERE/../wine-patches/0014-gdiplus-close-the-last-figure-in-GdipClosePathFigures.patch" \
         "$HERE/../wine-patches/0021-gdiplus-make-the-world-transform-relative-to-BeginContainer.patch" \
         "$HERE/../wine-patches/0023-gdiplus-fix-metafile-frame-bounds-pen-alignment-ResetClip-and-playback-space.patch" \
         "$HERE/../wine-patches/0024-gdiplus-tolerate-rounding-when-removing-repeated-path-points.patch"; do
  if git apply --check "$P" 2>/dev/null; then git apply "$P"
  elif git apply --reverse --check "$P" 2>/dev/null; then echo "$(basename "$P") already applied"
  else echo "$(basename "$P") neither applies nor is already applied" >&2; exit 1; fi
done
cd "$B" && make -j4 dlls/gdiplus/x86_64-windows/gdiplus.dll dlls/gdiplus/i386-windows/gdiplus.dll > make-gdiplus.log 2>&1
for a in x86_64 i386; do rm -f "$M/lib/wine/$a-windows/gdiplus.dll"; cp "$B/dlls/gdiplus/$a-windows/gdiplus.dll" "$M/lib/wine/$a-windows/gdiplus.dll"; done
echo "patched gdiplus.dll (64- and 32-bit) in $M"
# --- ieframe (PE) : WebBrowser fires ProgressChange when a download completes (patch 0015); Storyline's start page stays hidden until it does ---
P15="$HERE/../wine-patches/0015-ieframe-fire-ProgressChange-when-a-download-completes.patch"; cd "$SRC/wine-wine-11.16"
if git apply --check "$P15" 2>/dev/null; then git apply "$P15"
elif git apply --reverse --check "$P15" 2>/dev/null; then echo "$(basename "$P15") already applied"
else echo "$(basename "$P15") neither applies nor is already applied" >&2; exit 1; fi
cd "$B" && make -j4 dlls/ieframe/x86_64-windows/ieframe.dll dlls/ieframe/i386-windows/ieframe.dll > make-ieframe.log 2>&1
for a in x86_64 i386; do rm -f "$M/lib/wine/$a-windows/ieframe.dll"; cp "$B/dlls/ieframe/$a-windows/ieframe.dll" "$M/lib/wine/$a-windows/ieframe.dll"; done
echo "patched ieframe.dll (64- and 32-bit) in $M"
# --- windowscodecs (PE) : cache WIC component lists and GUID values (patch 0017); stock re-reads the registry about 97 times per decoded image ---
P17="$HERE/../wine-patches/0017-windowscodecs-cache-component-lists-and-GUID-values.patch"; cd "$SRC/wine-wine-11.16"
if git apply --check "$P17" 2>/dev/null; then git apply "$P17"
elif git apply --reverse --check "$P17" 2>/dev/null; then echo "WIC cache patch already applied"
else echo "patch 0017 neither applies nor is already applied" >&2; exit 1; fi
cd "$B" && make -j4 dlls/windowscodecs/x86_64-windows/windowscodecs.dll dlls/windowscodecs/i386-windows/windowscodecs.dll > make-windowscodecs.log 2>&1
for a in x86_64 i386; do rm -f "$M/lib/wine/$a-windows/windowscodecs.dll"; cp "$B/dlls/windowscodecs/$a-windows/windowscodecs.dll" "$M/lib/wine/$a-windows/windowscodecs.dll"; done
echo "patched windowscodecs.dll (64- and 32-bit) in $M"
# --- user32 (PE) : DrawText draws nothing into an inverted rectangle (patch 0019); without it Storyline's collapsed ribbon buttons still draw their labels over the next group ---
P19="$HERE/../wine-patches/0019-user32-draw-nothing-for-inverted-DrawText-rectangles.patch"; cd "$SRC/wine-wine-11.16"
if git apply --check "$P19" 2>/dev/null; then git apply "$P19"
elif git apply --reverse --check "$P19" 2>/dev/null; then echo "inverted DrawText rectangle patch already applied"
else echo "patch 0019 neither applies nor is already applied" >&2; exit 1; fi
# (patch 0028: DrawText treats a rectangle edge that wrapped around, like Storyline's point + int.MaxValue, as unbounded instead of clipping everything; the right panel's "New"/"Beta" badge text needs it)
P28="$HERE/../wine-patches/0028-user32-treat-DrawText-rectangle-edges-that-wrapped-around-as-unbounded.patch"
if git apply --check "$P28" 2>/dev/null; then git apply "$P28"
elif git apply --reverse --check "$P28" 2>/dev/null; then echo "wrapped DrawText rectangle patch already applied"
else echo "patch 0028 neither applies nor is already applied" >&2; exit 1; fi
cd "$B" && make -j4 dlls/user32/x86_64-windows/user32.dll dlls/user32/i386-windows/user32.dll > make-user32.log 2>&1
for a in x86_64 i386; do rm -f "$M/lib/wine/$a-windows/user32.dll"; cp "$B/dlls/user32/$a-windows/user32.dll" "$M/lib/wine/$a-windows/user32.dll"; done
echo "patched user32.dll (64- and 32-bit) in $M"
# --- imm32 (PE) : with no composition position and no caret, the IME candidate list goes to the bottom left of the focus window, as on Windows (patch 0027); Storyline sets neither, so macOS showed it at the top left of the screen ---
P27="$HERE/../wine-patches/0027-imm32-default-IME-composition-rect-at-the-bottom-left-of-the-focus-window.patch"; cd "$SRC/wine-wine-11.16"
if git apply --check "$P27" 2>/dev/null; then git apply "$P27"
elif git apply --reverse --check "$P27" 2>/dev/null; then echo "default IME composition rect patch already applied"
else echo "patch 0027 neither applies nor is already applied" >&2; exit 1; fi
cd "$B" && make -j4 dlls/imm32/x86_64-windows/imm32.dll dlls/imm32/i386-windows/imm32.dll > make-imm32.log 2>&1
for a in x86_64 i386; do rm -f "$M/lib/wine/$a-windows/imm32.dll"; cp "$B/dlls/imm32/$a-windows/imm32.dll" "$M/lib/wine/$a-windows/imm32.dll"; done
echo "patched imm32.dll (64- and 32-bit) in $M"
# Optional prefix name: also install the patched PE modules into that prefix's system32.
if [ -n "${1:-}" ]; then "$HERE/install-into-prefix.sh" "$1"; else echo "pass a prefix name, or run tools/wine-build/install-into-prefix.sh <prefix>"; fi
