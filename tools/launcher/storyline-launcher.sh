#!/bin/bash
# Dock launcher: runs the genuine Storyline.exe in the pinned Wine prefix on the patched Wine.
HERE="$(cd "$(dirname "$0")" && pwd)"
LAB="$HOME/StorylineLab"
export WINEARCH=win64 WINEPREFIX="$LAB/prefixes/wine-dotnet48-noadmintask" WINEDEBUG="${WINEDEBUG:--all}"
export PATH="/opt/local/bin:$PATH"
# A Mac .NET SDK's DOTNET_ROOT reaches Windows programs through Wine and points Storyline's apphost at a macOS runtime, so it asks to install the .NET Desktop Runtime.
unset DOTNET_ROOT DOTNET_ROOT_X64 DOTNET_ROOT_X86 DOTNET_ROOT_ARM64
# Research switch for the patched wined3d: report D3D feature level 10+ on MoltenVK (no geometry shaders).
export WINE_D3D_FL_RELAX=1
# Patched winemac (patch 0010): menu bar and Dock names per exe instead of "wine".
export WINE_MAC_APP_NAMES="Articulate 360 Desktop App.exe=Articulate 360;Storyline.exe=Storyline 360"
# Patched win32u (patch 0020): with RetinaMode on, Wine doubles Storyline's DPI-unaware windows with xBR instead of blurring them with halftone.
export WINE_SCALE_FILTER=xbr
. "$HERE/../Resources/storyline-args.sh"
mkdir -p "$LAB/logs/launcher"
# Start the Desktop Service now instead of when Storyline asks for it seconds later; a second copy exits on its own if one is already running.
(cd "$WINEPREFIX/drive_c/Program Files/Articulate/360/Desktop Service x64" && "$HERE/wine" "Articulate 360 Desktop Service.exe" >> "$LAB/logs/launcher/desktop-service.log" 2>&1 &)
cd "$WINEPREFIX/drive_c/Program Files/Articulate/360/Storyline 64-bit"
# Passed here too so a Wine build without patch 0018 still gets them; the patch skips switches already present.
exec "$HERE/wine" "Storyline.exe" ${WINE_APPEND_ARGS#Storyline.exe=} "$@" >> "$LAB/logs/launcher/storyline.log" 2>&1
