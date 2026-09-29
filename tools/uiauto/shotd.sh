#!/bin/bash
# Screenshot helper that runs inside Terminal, so captures use Terminal's Screen Recording permission; exits after 3 idle hours.
# Requests are files "<window-id> <out.png>" in /tmp/slshot/; started on demand by tools/uiauto/shot.sh.
Q=/tmp/slshot; mkdir -p "$Q"; echo $$ > "$Q/daemon.pid"
echo "Storyline screenshot helper (pid $$). Leave this window open; it closes itself after 3 idle hours."
idle=0
while [ "$idle" -lt 10800 ]; do
  found=0
  for r in "$Q"/*.req; do
    [ -f "$r" ] || continue
    found=1; read -r id out < "$r"
    screencapture -x -o -l "$id" "$out" && echo "$(date +%T) $out" || echo "$(date +%T) failed: $id $out"
    mv "$r" "${r%.req}.done"
  done
  if [ "$found" = 1 ]; then idle=0; else sleep 0.2; idle=$((idle + 1)); fi
done
rm -f "$Q/daemon.pid"
