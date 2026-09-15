#!/bin/bash
# Rebuild only ntdll.so from the pinned wine-11.16 source with the wow64 clamp patch, matching MacPorts' build settings.
# Prereqs (MacPorts): wine-devel 11.16, mingw-w64, bison, flex. Nothing here touches /opt/local.
set -euo pipefail
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
cp /opt/local/bin/wine "$M/bin/wine"; ln -sf /opt/local/bin/wineserver "$M/bin/wineserver"
echo "patched wine at $M/bin/wine"; "$M/bin/wine" --version
