#!/bin/bash
# Records one timed Storyline session under ~/StorylineLab/perf/<time>-<label>/ and writes summary.txt when Storyline quits.
# Usage: tools/perf/perf-session.sh <label> [--sample-clicks N] [VAR=value ...]   e.g. perf-session.sh caret --sample-clicks 3
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LAB="$HOME/StorylineLab"; LABEL="${1:?usage: perf-session.sh <label> [--sample-clicks N] [VAR=value ...]}"; shift
SAMPLE_CLICKS=0
if [ "${1:-}" = "--sample-clicks" ]; then SAMPLE_CLICKS="${2:?--sample-clicks needs a number}"; shift 2; fi
APP="$HOME/Applications/Storyline 360.app/Contents/MacOS/Storyline 360"
WINELOG="$LAB/logs/launcher/storyline.log"
SLLOGS="$LAB/prefixes/wine-dotnet48-noadmintask/drive_c/users/$USER/AppData/Local/Articulate/360/Logs"
[ -x "$APP" ] || { echo "Storyline launcher missing: run tools/launcher/install-launchers.sh" >&2; exit 1; }
if pgrep -f 'Storyline.exe' >/dev/null; then echo "quit Storyline first; the session has to start with a fresh process" >&2; exit 1; fi
for kv in "$@"; do [[ "$kv" == *=* ]] || { echo "not VAR=value: $kv" >&2; exit 1; }; done

S="$LAB/perf/$(date +%Y%m%d-%H%M%S)-$LABEL"; mkdir -p "$S"; ln -sfn "$S" "$LAB/perf/current"
{ echo "label=$LABEL"; echo "start_epoch=$(date +%s)"; echo "WINE_PERF_LOG=1"; printf '%s\n' "$@"; } > "$S/session.txt"
mkdir -p "$(dirname "$WINELOG")"; touch "$WINELOG"; offset=$(stat -f %z "$WINELOG")

# one row per Wine process per second: epoch,class,pid,cpu_seconds,rss_kb (CPU time is cumulative; the summary differences it)
( while :; do
    ps -axo pid=,time=,rss=,args= | awk -v ts="$(date +%s)" '
      { args = $0; sub(/^ *[0-9]+ +[0-9:.]+ +[0-9]+ +/, "", args); c = "" }
      args ~ /Storyline\.exe/ && args ~ /--type=gpu-process/ { c = "cef_gpu" }
      c == "" && args ~ /Storyline\.exe/ && args ~ /--type=renderer/ { c = "cef_renderer" }
      c == "" && args ~ /Storyline\.exe/ && args ~ /--type=/ { c = "cef_other" }
      c == "" && args ~ /Storyline\.exe/ { c = "storyline" }
      c == "" && args ~ /wineserver/ { c = "wineserver" }
      c == "" && args ~ /Articulate 360 Desktop App/ { c = "desktop_app" }
      c == "" && args ~ /Desktop Service/ { c = "desktop_service" }
      c == "" && args ~ /^[A-Z]:\\/ { c = "wine_other" }
      c != "" { n = split($2, t, ":"); s = 0; for (i = 1; i <= n; i++) s = s * 60 + t[i]; printf "%s,%s,%s,%.2f,%s\n", ts, c, $1, s, $3 }'
    sleep 1
  done ) > "$S/cpu.csv" &
SAMPLER=$!
WATCHER=""
cleanup() {
  kill "$SAMPLER" 2>/dev/null || true
  if [ -n "$WATCHER" ]; then kill "$WATCHER" 2>/dev/null || true; pkill -f "tail -n 0 -F $WINELOG" 2>/dev/null || true; fi
}
trap cleanup EXIT

# --sample-clicks: once a project has finished loading, sample Storyline after each of the next N clicks
if [ "$SAMPLE_CLICKS" -gt 0 ]; then
  # Storyline deletes its oldest log when it starts a new one, so compare marker timestamps with the session start rather than counting
  project_ready() {
    cat "$SLLOGS"/Storyline_STABLE*.log 2>/dev/null | LC_ALL=C grep -a 'ProjectReadyForBackgroundProcessing' | python3 -c '
import json, sys
from datetime import datetime
start = float(sys.argv[1])
for line in sys.stdin:
    try:
        if datetime.fromisoformat(json.loads(line)["@t"][:26].rstrip("Z") + "+00:00").timestamp() > start: sys.exit(0)
    except (ValueError, KeyError): pass
sys.exit(1)' "$(sed -n 's/^start_epoch=//p' "$S/session.txt")"
  }
  ( until project_ready; do sleep 2; done
    for i in $(seq 1 "$SAMPLE_CLICKS"); do
      echo ">>> click into a text box now (sample $i of $SAMPLE_CLICKS); keep Storyline open until the report prints"
      "$HERE/perf-sample-click.sh" 8 || break
    done
    echo ">>> sampling done; quit Storyline when you are finished" ) &
  WATCHER=$!
fi

echo "session $S — open a project and use Storyline normally; quit Storyline to finish"
[ "$SAMPLE_CLICKS" -gt 0 ] && echo "sampling starts automatically once the project has loaded"
env WINE_PERF_LOG=1 "$@" "$APP" || true
sleep 2; cleanup
echo "end_epoch=$(date +%s)" >> "$S/session.txt"

tail -c +"$((offset + 1))" "$WINELOG" | LC_ALL=C grep -a '^perf ' > "$S/wine-perf.log" || true
start=$(sed -n 's/^start_epoch=//p' "$S/session.txt")
for f in "$SLLOGS"/Storyline_STABLE*.log "$SLLOGS"/Storyline-CEF_*.log; do
  [ -f "$f" ] && [ "$(stat -f %m "$f")" -ge "$start" ] && cp "$f" "$S/" || true
done
python3 "$HERE/perf-summary.py" "$S" | tee "$S/summary.txt"
