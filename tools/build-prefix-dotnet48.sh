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
wineserver -w
echo "# winver:"; wine reg query 'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v CurrentBuildNumber | grep REG
echo "# net48 release:"; wine reg query 'HKLM\Software\Microsoft\NET Framework Setup\NDP\v4\Full' /v Release | grep REG
echo "# mono present?"; ls "$WINEPREFIX/drive_c/windows/mono" 2>/dev/null || echo "no (expected)"
echo "# end $(date -u +%FT%TZ)"
