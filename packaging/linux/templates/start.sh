#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu
GE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GE_DATA=${GOLDEN_ERA_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/golden-era-playtest}
case "$GE_DATA" in /*) ;; *) GE_DATA="$(pwd)/$GE_DATA" ;; esac
GE_APP=org.luanti.luanti
GE_CHECK=0
if [ "${1:-}" = --check ]; then GE_CHECK=1; shift; fi

fail() {
  printf '%s\n' "$1" >&2
  if [ "$GE_CHECK" = 0 ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    if command -v zenity >/dev/null 2>&1; then
      zenity --error --title='Golden Era Playtest' --text="$1" 2>/dev/null || true
    elif command -v xmessage >/dev/null 2>&1; then
      xmessage -center "$1" 2>/dev/null || true
    fi
  fi
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

version_ok() {
  printf '%s\n' "$1" | sed -n '1s/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*$/\1/p' |
    awk -F. 'NF==3 {found=1; if ($1>5 || ($1==5 && $2>=17)) valid=1} END {exit !(found && valid)}'
}

if [ "${1:-}" = --install-engine ]; then
  command -v flatpak >/dev/null 2>&1 || fail 'Flatpak is needed for this installation method. Install Flatpak using your Linux software manager, then open Install Luanti.flatpakref.'
  # This action is explicit. Normal game startup never installs or updates software.
  flatpak install --user --from "$GE_ROOT/Install Luanti.flatpakref"
  shift
fi

GE_BACKEND=
GE_VERSION=
if [ -n "${GOLDEN_ERA_ENGINE:-}" ]; then
  [ -x "$GOLDEN_ERA_ENGINE" ] || fail 'GOLDEN_ERA_ENGINE must point to an executable Luanti 5.17.0 or newer.'
  GE_ENGINE=$GOLDEN_ERA_ENGINE
  GE_VERSION=$("$GE_ENGINE" --version 2>/dev/null) || fail 'The selected Luanti engine could not start.'
  version_ok "$GE_VERSION" || fail 'The selected engine is too old. Golden Era needs Luanti 5.17.0 or newer.'
  GE_BACKEND=native
else
  for GE_CANDIDATE in luanti minetest; do
    if command -v "$GE_CANDIDATE" >/dev/null 2>&1; then
      GE_CANDIDATE_PATH=$(command -v "$GE_CANDIDATE")
      if GE_VERSION=$("$GE_CANDIDATE_PATH" --version 2>/dev/null) && version_ok "$GE_VERSION"; then
        GE_ENGINE=$GE_CANDIDATE_PATH
        GE_BACKEND=native
        break
      fi
    fi
  done
  if [ -z "$GE_BACKEND" ] && command -v flatpak >/dev/null 2>&1 && flatpak info "$GE_APP" >/dev/null 2>&1; then
    if GE_VERSION=$(flatpak run "$GE_APP" --version 2>/dev/null) && version_ok "$GE_VERSION"; then
      GE_BACKEND=flatpak
    fi
  fi
fi

[ -n "$GE_BACKEND" ] || fail 'Install Luanti 5.17.0 or newer, then open Play Golden Era again. On systems with Flatpak support, double-click Install Luanti.flatpakref. Terminal alternative: sh ./start.sh --install-engine. Your Linux software manager may provide an older engine that cannot run this pack.'
printf '%s\n' "Golden Era engine: $GE_BACKEND" "$(printf '%s\n' "$GE_VERSION" | sed -n '1p')" "Saves: $GE_DATA"
[ "$GE_CHECK" = 0 ] || exit 0

mkdir -p "$GE_DATA/worlds/playtest" "$GE_DATA/logs" "$GE_DATA/engine-user"
[ -f "$GE_DATA/settings.conf" ] || cp "$GE_ROOT/defaults/playtest.conf" "$GE_DATA/settings.conf"
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
if [ "$GE_BACKEND" = flatpak ]; then
  case "$GE_ROOT$GE_DATA" in *:*) fail 'Flatpak cannot use this game/save path because it contains a colon. Move the game or choose another GOLDEN_ERA_DATA_DIR.' ;; esac
  exec flatpak run --filesystem="$GE_ROOT:ro" --filesystem="$GE_DATA" \
    --env=LUANTI_GAME_PATH="$LUANTI_GAME_PATH" --env=LUANTI_USER_PATH="$LUANTI_USER_PATH" \
    "$GE_APP" --go --gameid golden_era_playtest --world "$GE_DATA/worlds/playtest" \
    --config "$GE_DATA/settings.conf" --logfile "$GE_DATA/logs/client.log" --name Tester "$@"
fi
exec "$GE_ENGINE" --go --gameid golden_era_playtest --world "$GE_DATA/worlds/playtest" \
  --config "$GE_DATA/settings.conf" --logfile "$GE_DATA/logs/client.log" --name Tester "$@"
