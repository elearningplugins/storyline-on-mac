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
mkdir -p "$LAB/logs/launcher"
cd "$WINEPREFIX/drive_c/Program Files/Articulate/360/Storyline 64-bit"
# --disable-gpu: CEF's ANGLE/D3D11 GPU process cannot initialise under Wine and otherwise restarts in a loop.
# --in-process-gpu: winemac can't show another process's drawing in a child window, so CEF's compositor must run inside Storyline or Preview and web panels stay blank.
exec "$HERE/wine" "Storyline.exe" --disable-gpu --in-process-gpu "$@" >> "$LAB/logs/launcher/storyline.log" 2>&1
