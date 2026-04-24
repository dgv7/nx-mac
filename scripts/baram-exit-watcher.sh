#!/bin/bash
# Baram exit watcher
# Policy: no residency. When Plug terminates (user closed window, or after game quit),
# tear down the entire wine tree so that nothing stays in background.

LOG=/tmp/baram-url-router.log
WRAPPER=/Users/eggxoxo/Applications/Sikarugir/Baram.app
WINESERVER="$WRAPPER/Contents/SharedSupport/wine/bin/wineserver"

echo "[exit-watcher] started pid=$$" >> "$LOG"

# Wait up to 120s for Plug to appear (CX24 cold-start takes ~45-50s)
for i in $(seq 1 60); do
  pgrep -f 'NexonPlug\.exe' > /dev/null 2>&1 && break
  sleep 2
done

if ! pgrep -f 'NexonPlug\.exe' > /dev/null 2>&1; then
  echo "[exit-watcher] NexonPlug.exe never appeared within 120s, cleanup then exit" >> "$LOG"
  pkill -9 -f 'wine/bin|winedevice|plugplay|services.exe|explorer.exe|conhost|svchost' 2>/dev/null
  "$WINESERVER" -k9 2>/dev/null
  echo "[exit-watcher] exit pid=$$ (plug-never-appeared)" >> "$LOG"
  exit 0
fi
echo "[exit-watcher] attached to Plug, monitoring" >> "$LOG"

GAME_STARTED=false
while pgrep -f 'NexonPlug\.exe' > /dev/null 2>&1; do
  if pgrep -f '/gamer\.exe' > /dev/null 2>&1 || pgrep -f '/BaramMedia\.exe' > /dev/null 2>&1; then
    if [ "$GAME_STARTED" = "false" ]; then
      echo "[exit-watcher] game running, armed" >> "$LOG"
      GAME_STARTED=true
    fi
  elif [ "$GAME_STARTED" = "true" ]; then
    echo "[exit-watcher] game ended, 3s grace" >> "$LOG"
    sleep 3
    break
  fi
  sleep 2
done

# Reached either by:
#   (a) Plug terminated (user closed window) — GAME_STARTED may be false or true
#   (b) Game ended, break above — GAME_STARTED=true
# Either way: no-residency policy → full wine tree teardown.
echo "[exit-watcher] teardown wine tree (no-residency)" >> "$LOG"
pkill -9 -f 'wine/bin|winedevice|plugplay|services.exe|explorer.exe|conhost|svchost' 2>/dev/null
pkill -9 -f 'NexonPlug|PlugRender|NGM64|NexonLauncher|gamer.exe|BaramMedia|Kingdom of the' 2>/dev/null
"$WINESERVER" -k9 2>/dev/null
echo "[exit-watcher] exit pid=$$ (game-started=$GAME_STARTED)" >> "$LOG"
