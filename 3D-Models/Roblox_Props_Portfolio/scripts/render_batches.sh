#!/bin/bash
# Renders the given frames in small batches (one Blender process per batch) to keep memory low.
cd "$(dirname "$0")/.."
SNAP=${SNAP:-/tmp/claude-1000/-home-dani-pp/deff6017-7aae-40ab-94b9-3cd92c19e5a9/scratchpad/render_snapshot.blend}
cp blend/Roblox_Props_Portfolio.blend "$SNAP"
exec 9>"/tmp/claude-1000/-home-dani-pp/deff6017-7aae-40ab-94b9-3cd92c19e5a9/scratchpad/render.lock"; flock 9
frames=("$@"); n=${#frames[@]}
for ((i=0; i<n; i+=4)); do
  PP_SAMPLES=${PP_SAMPLES:-40} blender -b "$SNAP" -P scripts/render_all.py -- "${frames[@]:i:4}" 2>&1 | grep -E "RENDERED|Error"
done
echo BATCHES_DONE
