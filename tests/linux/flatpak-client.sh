#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Developer GUI transport for the repository-only official Flatpak installation.
# Run via tests/playtest/gui.py --engine tests/linux/flatpak-client.sh.
set -eu
GE_REPO=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
GE_INSTALL="$GE_REPO/runtime/tests/linux-flatpak"
case "${LUANTI_GAME_PATH:-}" in
  "$GE_REPO"/runtime/tests/*/games) ;;
  *) printf '%s\n' 'This wrapper only accepts disposable GUI test games inside runtime/tests.' >&2; exit 1 ;;
esac
GE_WORK=$(dirname -- "$LUANTI_GAME_PATH")
case "${XAUTHORITY:-}" in
  "$GE_WORK"/*) ;;
  *) printf '%s\n' 'Use the private test Xauthority file.' >&2; exit 1 ;;
esac
FLATPAK_USER_DIR="$GE_INSTALL/installation"
XDG_CACHE_HOME="$GE_INSTALL/cache"
XDG_DATA_HOME="$GE_INSTALL/data"
XDG_CONFIG_HOME="$GE_INSTALL/config"
export FLATPAK_USER_DIR XDG_CACHE_HOME XDG_DATA_HOME XDG_CONFIG_HOME
GE_APP=$(flatpak info --user --show-location org.luanti.luanti)
# Running the exact app binary inside its matching runtime avoids the ordinary
# app wrapper's ~/.var/app writes. This does not validate the ordinary app entry.
exec flatpak run --app-path="$GE_APP/files" --command=/app/bin/luanti.bin \
  --socket=x11 --filesystem="$GE_WORK" \
  --env=DISPLAY="$DISPLAY" --env=XAUTHORITY="$XAUTHORITY" \
  --env=SDL_VIDEODRIVER=x11 --env=LIBGL_ALWAYS_SOFTWARE=1 \
  --env=ALSOFT_DRIVERS=null \
  --env=LUANTI_GAME_PATH="$LUANTI_GAME_PATH" --env=LUANTI_USER_PATH="$GE_WORK/engine-user" \
  --env=XDG_CACHE_HOME="$GE_WORK/engine-cache" --env=XDG_DATA_HOME="$GE_WORK/engine-data" \
  --env=XDG_CONFIG_HOME="$GE_WORK/engine-config" \
  org.freedesktop.Platform//26.08 "$@"
