#!/bin/bash
# Hands-off caret session: launches Storyline under perf-session, opens a new project, adds two text boxes, clicks into them repeatedly, quits without saving and prints the summary.
# Usage: tools/perf/auto-caret.sh [label] [clicks] [VAR=value ...]   e.g. auto-caret.sh baseline 8 · auto-caret.sh gen0 8 DOTNET_GCgen0size=0x4000000
# NO_TYPING=1 only clicks into the boxes and leaves them, so no edits pile up between clicks.
# SAMPLE_AT="5 7" records a macOS sample of the main process for 7 s after those clicks (reports land in the session folder).
# Ribbon coordinates assume the maximised 1440x817 Storyline window on this Mac's 1440x900 display; screenshots land in the session folder.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; SL="$HERE/../uiauto/sl"; SHOT="$HERE/../uiauto/shot.sh"
LABEL="${1:-auto-caret}"; CLICKS="${2:-8}"; shift $(( $# < 2 ? $# : 2 ))
LOG="/tmp/$LABEL-session.log"
step() { echo "[$(date +%H:%M:%S)] $*"; }
shot() { "$SHOT" "$HOME/StorylineLab/perf/current/$1.png" >/dev/null 2>&1 || true; }
fail() { step "failed: $*"; shot failure; step "Storyline left open for inspection; session log: $LOG"; exit 1; }

nohup "$HERE/perf-session.sh" "$LABEL" "$@" > "$LOG" 2>&1 &
PS=$!
step "session started (perf-session pid $PS); waiting for the start screen"
sleep 5
"$SL" waittext "&New Project" 180 >/dev/null || fail "start screen never showed New Project"
sleep 5
# mouse clicks on the start screen are often ignored, but its Alt+N mnemonic always works
for _ in 1 2 3; do
  "$SL" focus "Articulate Storyline" >/dev/null; "$SL" keys "{ALT+N}"
  "$SL" wait "Untitled1" 30 >/dev/null && break
done
"$SL" wait "Untitled1" 1 >/dev/null || fail "New Project did not open"
"$SL" waittext "STORY VIEW" 120 >/dev/null || fail "story view never appeared"
step "project open; opening the first slide"
sleep 10
"$SL" dclick 541 325
"$SL" waittext "Timeline, States, Notes" 60 >/dev/null || fail "slide view did not open"
sleep 8

step "adding two text boxes"
for y in 300 450; do
  "$SL" click 149 69; sleep 2
  "$SL" click 913 116; sleep 2
  "$SL" drag 350 "$y" 750 $((y + 60)); sleep 3
  "$SL" keys "Text box at $y"; sleep 2
  "$SL" keys "{ESC}{ESC}"; sleep 2
done
shot boxes

step "clicking into the text boxes $CLICKS times"
for i in $(seq 1 "$CLICKS"); do
  y=$(( i % 2 ? 330 : 480 ))
  SAMPLER=""
  if [[ " ${SAMPLE_AT:-} " == *" $i "* ]]; then "$HERE/perf-sample-click.sh" 7 > "/tmp/$LABEL-sample-$i.log" 2>&1 & SAMPLER=$!; sleep 1; fi
  "$SL" click 550 "$y"; sleep 3
  [ -z "$SAMPLER" ] || wait "$SAMPLER" || true
  [ -n "${NO_TYPING:-}" ] || { "$SL" keys " $i"; sleep 1; }
  "$SL" keys "{ESC}{ESC}"; sleep 2
done
shot clicks

step "quitting without saving"
"$SL" close "Articulate Storyline" >/dev/null
"$SL" clicktext "Do&n't Save" 30 >/dev/null || fail "save prompt did not appear"
for _ in $(seq 1 180); do kill -0 "$PS" 2>/dev/null || break; sleep 1; done
kill -0 "$PS" 2>/dev/null && fail "Storyline did not exit"
cat "$LOG"
