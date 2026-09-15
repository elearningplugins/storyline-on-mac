#!/bin/bash
# Usage: run-wine-logged.sh <prefix-name> <log-dir> <exe> [args...]
set -euo pipefail
LAB="$HOME/StorylineLab"
WINE=/opt/local/bin/wine
PREFIX_NAME="$1"; LOGDIR="$LAB/logs/$2"; shift 2
export WINEARCH=win64
export WINEPREFIX="$LAB/prefixes/$PREFIX_NAME"
export WINEDEBUG="${WINEDEBUG:-+timestamp,+pid,+tid,+seh,+loaddll,+msi,+service}"
mkdir -p "$LOGDIR"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$LOGDIR/$STAMP.log"
{
  echo "# macOS $(sw_vers -productVersion) $(sw_vers -buildVersion) $(uname -m)"
  echo "# wine: $($WINE --version)  ($(/opt/local/bin/port -q installed wine-devel | tr -d '\n'))"
  echo "# prefix: $WINEPREFIX"
  echo "# winver: $($WINE reg query 'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v CurrentBuildNumber 2>/dev/null | grep -o 'REG_SZ.*' || echo unknown)"
  echo "# input: $(shasum -a 256 "$1")"
  echo "# cmd: $WINE $*"
  echo "# start: $(date -u +%FT%TZ)"
} | tee "$LOG"
set +e
"$WINE" "$@" 2>>"$LOG"
RC=$?
echo "# exit: $RC  end: $(date -u +%FT%TZ)" | tee -a "$LOG"
echo "log: $LOG"
exit $RC
