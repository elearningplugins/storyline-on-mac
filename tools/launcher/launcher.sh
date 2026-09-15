#!/bin/bash
# Dock launcher: runs the genuine Articulate 360 Desktop App in the pinned Wine prefix.
HERE="$(cd "$(dirname "$0")" && pwd)"
LAB="$HOME/StorylineLab"
export WINEARCH=win64 WINEPREFIX="$LAB/prefixes/wine-dotnet48-noadmintask" WINEDEBUG=-all
export PATH="/opt/local/bin:$PATH"
# Research switch for the patched wined3d: report D3D feature level 10+ on MoltenVK (no geometry shaders).
export WINE_D3D_FL_RELAX=1
mkdir -p "$LAB/logs/launcher"
cd "$WINEPREFIX/drive_c/Program Files/Articulate/360/Desktop Application x64"
exec "$HERE/wine" "Articulate 360 Desktop App.exe" "$@" >> "$LAB/logs/launcher/launcher.log" 2>&1
