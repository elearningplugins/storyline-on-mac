#!/bin/bash
# Phase 2: install VC++ x86/x64 and the official core MSI directly into an existing prefix, bypassing Burn.
set -uo pipefail
LAB="$HOME/StorylineLab"; NAME="$1"; PAY="$LAB/inputs/burn-payloads"; LOGD="$LAB/logs/core-direct-$NAME"; mkdir -p "$LOGD"
export WINEARCH=win64 WINEPREFIX="$LAB/prefixes/$NAME" WINEDEBUG=-all
cd "$PAY"
for r in vc_redist.x86.exe vc_redist.x64.exe; do
  /opt/local/bin/wine "$r" /install /quiet /norestart; echo "$r exit=$?" | tee -a "$LOGD/summary.txt"
done
/opt/local/bin/wineserver -w
WINEDEBUG=+timestamp,+pid,+tid,+seh,+msi,+service /opt/local/bin/wine msiexec /i Articulate.360.Package.msi /qn /L*v "C:\\core-msi.log" 2>"$LOGD/wine-msi.log"; echo "core msi exit=$?" | tee -a "$LOGD/summary.txt"
/opt/local/bin/wineserver -w
cp "$WINEPREFIX/drive_c/core-msi.log" "$LOGD/core-msi.log" 2>/dev/null
ls "$WINEPREFIX/drive_c/Program Files/Articulate/360/" 2>&1 | tee -a "$LOGD/summary.txt"
