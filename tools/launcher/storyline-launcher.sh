#!/bin/bash
# Dock launcher: runs the genuine Storyline.exe in the pinned Wine prefix on the patched Wine.
HERE="$(cd "$(dirname "$0")" && pwd)"
LAB="$HOME/StorylineLab"
export WINEARCH=win64 WINEPREFIX="$LAB/prefixes/wine-dotnet48-noadmintask" WINEDEBUG="${WINEDEBUG:--all}"
export PATH="/opt/local/bin:$PATH"
# Research switch for the patched wined3d: report D3D feature level 10+ on MoltenVK (no geometry shaders).
export WINE_D3D_FL_RELAX=1
# Patched winemac (patch 0010): menu bar and Dock names per exe instead of "wine".
export WINE_MAC_APP_NAMES="Articulate 360 Desktop App.exe=Articulate 360;Storyline.exe=Storyline 360"
. "$HERE/../Resources/storyline-args.sh"
mkdir -p "$LAB/logs/launcher"
cd "$WINEPREFIX/drive_c/Program Files/Articulate/360/Storyline 64-bit"
# Passed here too so a Wine build without patch 0018 still gets them; the patch skips switches already present.
exec "$HERE/wine" "Storyline.exe" ${WINE_APPEND_ARGS#Storyline.exe=} "$@" >> "$LAB/logs/launcher/storyline.log" 2>&1
