#!/bin/bash
# Dock launcher: runs the genuine Articulate 360 Desktop App in the pinned Wine prefix.
HERE="$(cd "$(dirname "$0")" && pwd)"
LAB="$HOME/StorylineLab"
export WINEARCH=win64 WINEPREFIX="$LAB/prefixes/wine-dotnet48-noadmintask" WINEDEBUG=-all
export PATH="/opt/local/bin:$PATH"
# Storyline started from the Desktop App inherits its environment; a Mac .NET SDK's DOTNET_ROOT would make its apphost ask to install the .NET Desktop Runtime.
unset DOTNET_ROOT DOTNET_ROOT_X64 DOTNET_ROOT_X86 DOTNET_ROOT_ARM64
# Research switch for the patched wined3d: report D3D feature level 10+ on MoltenVK (no geometry shaders).
export WINE_D3D_FL_RELAX=1
# Patched winemac (patch 0010): menu bar and Dock names per exe, so Storyline opened from the Desktop App is not shown as "wine".
export WINE_MAC_APP_NAMES="Articulate 360 Desktop App.exe=Articulate 360;Storyline.exe=Storyline 360"
# Patched win32u (patch 0020): Storyline started from the Desktop App inherits this, so its windows are doubled with xBR too.
export WINE_SCALE_FILTER=xbr
. "$HERE/../Resources/storyline-args.sh"
mkdir -p "$LAB/logs/launcher"
cd "$WINEPREFIX/drive_c/Program Files/Articulate/360/Desktop Application x64"
exec "$HERE/wine" "Articulate 360 Desktop App.exe" "$@" >> "$LAB/logs/launcher/launcher.log" 2>&1
