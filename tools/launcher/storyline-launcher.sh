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
mkdir -p "$LAB/logs/launcher"
cd "$WINEPREFIX/drive_c/Program Files/Articulate/360/Storyline 64-bit"
# --disable-gpu: CEF's ANGLE/D3D11 GPU process cannot initialise under Wine and otherwise restarts in a loop.
exec "$HERE/wine" "Storyline.exe" --disable-gpu "$@" >> "$LAB/logs/launcher/storyline.log" 2>&1
