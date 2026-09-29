#!/bin/bash
# Adds a timestamped note to the running perf session, e.g. perf-mark.sh "File > New clicked".
set -euo pipefail
S="$HOME/StorylineLab/perf/current"
[ -d "$S" ] || { echo "no perf session found" >&2; exit 1; }
printf '%s\t%s\n' "$(python3 -c 'import time; print(f"{time.time():.3f}")')" "$*" >> "$S/marks.tsv"
echo "marked: $*"
