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
elif command -v flatpak >/dev/null 2>&1 && flatpak info net.minetest.Minetest >/dev/null 2>&1; then
  exec flatpak run --filesystem="$GE_ROOT:ro" --filesystem="$GE_DATA" \
    --env=LUANTI_GAME_PATH="$LUANTI_GAME_PATH" --env=LUANTI_USER_PATH="$LUANTI_USER_PATH" \
    net.minetest.Minetest --go --gameid golden_era_playtest --world "$GE_DATA/worlds/playtest" \
    --config "$GE_DATA/settings.conf" --logfile "$GE_DATA/logs/client.log" --name Tester "$@"
else
  printf '%s\n' 'Install Luanti 5.17.0 from https://www.luanti.org/en/downloads/ then run start.sh again.' >&2
  printf '%s\n' 'Advanced: GOLDEN_ERA_ENGINE can point to a compatible Luanti executable.' >&2
  exit 1
fi
exec "$GE_ENGINE" --go --gameid golden_era_playtest --world "$GE_DATA/worlds/playtest" \
  --config "$GE_DATA/settings.conf" --logfile "$GE_DATA/logs/client.log" --name Tester "$@"
