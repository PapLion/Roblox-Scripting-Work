#!/bin/bash
# Serial render queue: snapshot now, then wait for older queues and hold an exclusive lock while rendering.
cd "$(dirname "$0")/.."
SP=/tmp/claude-1000/-home-dani-pp/deff6017-7aae-40ab-94b9-3cd92c19e5a9/scratchpad
SNAP=$SP/serial_$$.blend
cp blend/Roblox_Props_Portfolio.blend "$SNAP"
exec 9>"$SP/render.lock"
flock 9
for ((i=1; i<=$#; i+=4)); do
  PP_SAMPLES=${PP_SAMPLES:-40} blender -b "$SNAP" -P scripts/render_all.py -- "${@:i:4}" 2>&1 | grep -E "RENDERED|Error"
done
rm -f "$SNAP"; echo SERIAL_DONE "$@"
