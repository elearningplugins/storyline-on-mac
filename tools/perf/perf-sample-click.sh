#!/bin/bash
# Waits for the next click in a running perf session, then records a macOS `sample` of Storyline's main process for N seconds (default 8).
# Usage: tools/perf/perf-sample-click.sh [seconds]   (start perf-session.sh first; output goes to the session folder)
set -euo pipefail
SECS="${1:-8}"; LOG="$HOME/StorylineLab/logs/launcher/storyline.log"; S="$HOME/StorylineLab/perf/current"
PID=$(pgrep -f 'Storyline\.exe' | while read -r p; do ps -o args= -p "$p" | grep -q -- '--type=' || echo "$p"; done | head -1)
[ -n "$PID" ] || { echo "Storyline is not running; start tools/perf/perf-session.sh first" >&2; exit 1; }
echo "waiting for a click in Storyline (pid $PID)…"
tail -n 0 -F "$LOG" 2>/dev/null | LC_ALL=C grep -a -m1 'win32u input mouse_down' >/dev/null || true
OUT="$S/sample-$(date +%H%M%S).txt"
echo "click seen; sampling for $SECS s"
echo "$(python3 -c 'import time; print(f"{time.time():.3f}")')	sample started: $(basename "$OUT")" >> "$S/marks.tsv"
sample "$PID" "$SECS" 1 -mayDie -file "$OUT" >/dev/null 2>&1 || true
# the memory map names the Windows modules that `sample` shows as "???"; take it while the process is still up
vmmap -wide "$PID" > "${OUT%.txt}-vmmap.txt" 2>/dev/null || true
python3 "$(dirname "$0")/perf-sample-report.py" "$OUT" "${OUT%.txt}-vmmap.txt" | tee "${OUT%.txt}-report.txt"
