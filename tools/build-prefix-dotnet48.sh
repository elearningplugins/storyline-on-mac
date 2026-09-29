#!/bin/bash
# Builds a clean win64 prefix: real .NET 4.8 + corefonts, Windows 10 mode, DisableNonAdminInstalls=true.
set -euo pipefail
LAB="$HOME/StorylineLab"; NAME="${1:-wine-dotnet48-noadmintask}"
export PATH="/opt/local/bin:$PATH" WINE=/opt/local/bin/wine WINEARCH=win64 WINEPREFIX="$LAB/prefixes/$NAME" WINEDEBUG=-all
export WINETRICKS_CACHE="$LAB/inputs/winetricks-cache"; mkdir -p "$WINETRICKS_CACHE"
[ -e "$WINEPREFIX" ] && { echo "prefix exists: $WINEPREFIX"; exit 1; }
echo "# start $(date -u +%FT%TZ)"; wineboot -u
"$LAB/tools/winetricks" -q --unattended dotnet48 corefonts
"$LAB/tools/winetricks" -q win10
wine reg add 'HKLM\Software\Articulate\Common\Settings' /v DisableNonAdminInstalls /t REG_SZ /d true /f
# WPF software rendering: through wined3d on MoltenVK the Desktop App draws clipped labels and stray lines; OpenGL draws nothing.
wine reg add 'HKCU\Software\Microsoft\Avalon.Graphics' /v DisableHWAcceleration /t REG_DWORD /d 1 /f
# Vulkan renderer: GL stops at feature level 9_3; the patched wined3d reaches 11_1 on MoltenVK (Run 10).
wine reg add 'HKCU\Software\Wine\Direct3D' /v renderer /t REG_SZ /d vulkan /f
# Mac driver: Command keys act as Ctrl; RetinaMode off because WPF dialogs went blank with it on (Run 04e).
wine reg add 'HKCU\Software\Wine\Mac Driver' /v LeftCommandIsCtrl /t REG_SZ /d y /f
wine reg add 'HKCU\Software\Wine\Mac Driver' /v RightCommandIsCtrl /t REG_SZ /d y /f
wine reg add 'HKCU\Software\Wine\Mac Driver' /v RetinaMode /t REG_SZ /d n /f
# Busy and app-starting cursors map to the native arrow; macOS has no app busy cursor (Run 11).
wine reg add 'HKCU\Software\Wine\Mac Driver\Cursors' /v 'user32.dll,32514' /t REG_SZ /d arrowCursor /f
wine reg add 'HKCU\Software\Wine\Mac Driver\Cursors' /v 'user32.dll,32650' /t REG_SZ /d arrowCursor /f
wineserver -w
echo "# winver:"; wine reg query 'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v CurrentBuildNumber | grep REG
echo "# net48 release:"; wine reg query 'HKLM\Software\Microsoft\NET Framework Setup\NDP\v4\Full' /v Release | grep REG
echo "# mono present?"; ls "$WINEPREFIX/drive_c/windows/mono" 2>/dev/null || echo "no (expected)"
echo "# end $(date -u +%FT%TZ)"
