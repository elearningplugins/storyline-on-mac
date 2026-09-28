#!/bin/bash
# Lays out the Articulate 360 core without its custom actions (Run 04c): VC++ runtimes, msiexec /a, copy into Program Files, import the installer's registry keys.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LAB="$HOME/StorylineLab"; NAME="${1:-wine-dotnet48-noadmintask}"; PAY="$LAB/inputs/burn-payloads"
export PATH="/opt/local/bin:$PATH" WINEARCH=win64 WINEPREFIX="$LAB/prefixes/$NAME" WINEDEBUG=-all
[ -d "$WINEPREFIX" ] || { echo "no such prefix: $WINEPREFIX (build it with tools/build-prefix-dotnet48.sh)"; exit 1; }
cd "$PAY"
for f in vc_redist.x86.exe vc_redist.x64.exe Articulate.360.Package.msi; do
  [ -f "$f" ] || { echo "missing input: $PAY/$f"; exit 1; }
  grep -q "  $f\$" "$HERE/../SHA256SUMS" && shasum -a 256 -c <(grep "  $f\$" "$HERE/../SHA256SUMS")
done
for r in vc_redist.x86.exe vc_redist.x64.exe; do wine "$r" /install /quiet /norestart || echo "$r exit=$? (1638 = already installed)"; done
wineserver -w
C="$WINEPREFIX/drive_c"
wine msiexec /a Articulate.360.Package.msi /qn TARGETDIR='C:\ArticulateAdminImage' /L*v 'C:\core-msi-admin.log'
wineserver -w
mkdir -p "$C/Program Files/Articulate"
cp -R "$C/ArticulateAdminImage/Articulate/360" "$C/Program Files/Articulate/"
for r in articulate-hklm articulate-protocol; do wine regedit /S "$(winepath -w "$HERE/prefix-reg/$r.reg")"; done
wineserver -w
wine reg query 'HKLM\Software\Articulate\360\Desktop Application' /v 'Install Location' | grep REG
ls "$C/Program Files/Articulate/360/"
