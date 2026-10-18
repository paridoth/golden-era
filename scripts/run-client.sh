#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export LD_LIBRARY_PATH="$PWD/tools/client-root/usr/lib/x86_64-linux-gnu:$PWD/tools/root/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LUANTI_GAME_PATH="$PWD/runtime/games"
mkdir -p runtime/worlds/play
exec upstream/luanti/bin/luanti --gameid golden_era --port 30099 --world "$PWD/runtime/worlds/play" --config "$PWD/server.conf" "$@"
