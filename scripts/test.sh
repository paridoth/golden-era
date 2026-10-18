#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tools/root/usr/bin/lua5.1 tests/unit/test_ledger.lua
if [[ "${1:-}" == "--integration" ]]; then python3 tests/integration/run.py; fi
