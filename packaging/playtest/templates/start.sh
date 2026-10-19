#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu
GE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -n "${GOLDEN_ERA_DATA_DIR:-}" ]; then
  GE_DATA=$GOLDEN_ERA_DATA_DIR
elif [ "$(uname -s)" = Darwin ]; then
  GE_DATA="$HOME/Library/Application Support/GoldenEraPlaytest"
else
  GE_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/golden-era-playtest"
fi
case "$GE_DATA" in /*) ;; *) GE_DATA="$(pwd)/$GE_DATA" ;; esac
fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

# Read-only preflight: never relabel an existing world or write settings before
# its effective final game ID has been checked. Luanti keys are case-sensitive.
GE_WORLD="$GE_DATA/worlds/playtest"
if [ -e "$GE_WORLD/world.mt" ] || [ -L "$GE_WORLD/world.mt" ]; then
  if [ ! -f "$GE_WORLD/world.mt" ] || ! LC_ALL=C awk '
    /^[[:space:]]*#/ { next }
    /^[^=]*=[[:space:]]*(\{|""")[[:space:]]*$/ { structured=1 }
    /^[[:space:]]*gameid[[:space:]]*=/ {
      value=$0
      sub(/^[[:space:]]*gameid[[:space:]]*=[[:space:]]*/, "", value)
      sub(/[[:space:]]*$/, "", value)
      found=1
    }
    END { exit !(found && value=="golden_era_playtest" && !structured) }
  ' "$GE_WORLD/world.mt"; then
    fail 'This save belongs to another game or has no unambiguous Golden Era game ID. Choose a different GOLDEN_ERA_DATA_DIR; existing files were left unchanged.'
  fi
else
  for GE_MARKER in map.sqlite map.db map.sqlite-wal map_meta.txt players.sqlite auth.sqlite auth.txt mod_storage.sqlite players; do
    if [ -e "$GE_WORLD/$GE_MARKER" ] || [ -L "$GE_WORLD/$GE_MARKER" ]; then
      fail 'This save has world data but no world.mt. Restore its world.mt or choose a different GOLDEN_ERA_DATA_DIR; existing files were left unchanged.'
    fi
  done
fi

mkdir -p "$GE_DATA/worlds/playtest" "$GE_DATA/logs" "$GE_DATA/engine-user"
if [ ! -f "$GE_DATA/settings.conf" ]; then
  cp "$GE_ROOT/defaults/playtest.conf" "$GE_DATA/settings.conf"
fi
if [ ! -f "$GE_DATA/worlds/playtest/world.mt" ]; then
  cat > "$GE_DATA/worlds/playtest/world.mt" <<'WORLD'
gameid = golden_era_playtest
backend = sqlite3
player_backend = sqlite3
auth_backend = sqlite3
mod_storage_backend = sqlite3
WORLD
fi
LUANTI_GAME_PATH="$GE_ROOT/games"
LUANTI_USER_PATH="$GE_DATA/engine-user"
export LUANTI_GAME_PATH LUANTI_USER_PATH
if [ -n "${GOLDEN_ERA_ENGINE:-}" ]; then
  GE_ENGINE=$GOLDEN_ERA_ENGINE
elif command -v luanti >/dev/null 2>&1; then
  GE_ENGINE=$(command -v luanti)
elif [ -x /Applications/Luanti.app/Contents/MacOS/luanti ]; then
  GE_ENGINE=/Applications/Luanti.app/Contents/MacOS/luanti
elif [ -x /Applications/Minetest.app/Contents/MacOS/minetest ]; then
  GE_ENGINE=/Applications/Minetest.app/Contents/MacOS/minetest
elif command -v flatpak >/dev/null 2>&1 && flatpak info org.luanti.luanti >/dev/null 2>&1; then
  exec flatpak run --filesystem="$GE_ROOT:ro" --filesystem="$GE_DATA" \
    --env=LUANTI_GAME_PATH="$LUANTI_GAME_PATH" --env=LUANTI_USER_PATH="$LUANTI_USER_PATH" \
    org.luanti.luanti --go --gameid golden_era_playtest --world "$GE_DATA/worlds/playtest" \
    --config "$GE_DATA/settings.conf" --logfile "$GE_DATA/logs/client.log" --name Tester "$@"
else
  printf '%s\n' 'Install Luanti 5.17.0 from https://www.luanti.org/en/downloads/ then run start.sh again.' >&2
  printf '%s\n' 'Advanced: GOLDEN_ERA_ENGINE can point to a compatible Luanti executable.' >&2
  exit 1
fi
exec "$GE_ENGINE" --go --gameid golden_era_playtest --world "$GE_DATA/worlds/playtest" \
  --config "$GE_DATA/settings.conf" --logfile "$GE_DATA/logs/client.log" --name Tester "$@"
