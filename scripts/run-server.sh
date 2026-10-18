#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export LD_LIBRARY_PATH="$PWD/tools/root/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LUANTI_GAME_PATH="$PWD/runtime/games"
mkdir -p runtime/worlds/play
exec upstream/luanti/bin/luantiserver --gameid golden_era --world "$PWD/runtime/worlds/play" --config "$PWD/server.conf" "$@"
