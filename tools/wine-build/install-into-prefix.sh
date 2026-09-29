#!/bin/bash
# Copies the patched PE modules from the wine-patched mirror into a prefix's system32, which keeps its own copies of these DLLs.
set -euo pipefail
LAB="$HOME/StorylineLab"; NAME="${1:?usage: install-into-prefix.sh <prefix-name>}"
M="$LAB/wine-patched/lib/wine/x86_64-windows"; S="$LAB/prefixes/$NAME/drive_c/windows/system32"
[ -d "$S" ] || { echo "no such prefix: $S"; exit 1; }
for f in dwrite wined3d d2d1 win32u; do
  # copy then rename so a running Wine process keeps its mapped copy instead of seeing the file change under it
  cp "$M/$f.dll" "$S/.$f.dll.new" && mv -f "$S/.$f.dll.new" "$S/$f.dll"
  echo "installed $f.dll -> $S"
done
