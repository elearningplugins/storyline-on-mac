#!/bin/bash
# Saves a PNG of Storyline's largest window (or the pid given) via the Terminal-hosted helper; prints the path and the window's screen bounds.
# Usage: tools/uiauto/shot.sh <out.png> [pid]   (Terminal needs Screen Recording permission in System Settings)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; OUT="${1:?usage: shot.sh <out.png> [pid]}"; Q=/tmp/slshot; B="$HOME/StorylineLab/tools/uiauto"
PID="${2:-$(pgrep -f 'Storyline\.exe' | while read -r p; do ps -o args= -p "$p" | grep -q -- '--type=' || echo "$p"; done | head -1)}"
[ -n "$PID" ] || { echo "Storyline is not running" >&2; exit 1; }
mkdir -p "$B" "$Q"
[ -x "$B/winid" ] && [ "$B/winid" -nt "$HERE/winid.swift" ] || swiftc -O -o "$B/winid" "$HERE/winid.swift"
read -r WID X Y W H < <("$B/winid" "$PID" | head -1) || { echo "no on-screen window for pid $PID" >&2; exit 1; }
if ! { [ -f "$Q/daemon.pid" ] && kill -0 "$(cat "$Q/daemon.pid")" 2>/dev/null; }; then
  printf '#!/bin/bash\nexec "%s"\n' "$HERE/shotd.sh" > "$B/shotd.command"; chmod +x "$B/shotd.command" "$HERE/shotd.sh"
  open -g -a Terminal "$B/shotd.command"
  for _ in $(seq 1 50); do [ -f "$Q/daemon.pid" ] && break; sleep 0.2; done
fi
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT";; esac
# Storyline stops repainting while its window is behind another app, so bring it forward for the capture and hand focus back afterwards.
PREV=$(osascript -e 'tell application "System Events" to get unix id of first process whose frontmost is true' 2>/dev/null || true)
osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $PID) to true" >/dev/null 2>&1 || true
sleep "${SHOT_SETTLE:-2}"
rm -f "$OUT"; R="$Q/$(date +%s%N).req"; echo "$WID $OUT" > "$R.tmp"; mv "$R.tmp" "$R"
for _ in $(seq 1 50); do [ -f "$OUT" ] && break; sleep 0.2; done
[ -z "$PREV" ] || [ "$PREV" = "$PID" ] || [ -n "${SHOT_KEEP_FRONT:-}" ] || osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $PREV) to true" >/dev/null 2>&1 || true
[ -f "$OUT" ] || { echo "screenshot timed out (is the helper running in Terminal?)" >&2; exit 1; }
echo "$OUT window=$WID bounds=$X,$Y ${W}x$H"
