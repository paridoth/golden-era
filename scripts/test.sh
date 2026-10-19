#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tools/root/usr/bin/lua5.1 tests/unit/test_ledger.lua
tools/root/usr/bin/lua5.1 tests/unit/test_thermal_model.lua
tools/root/usr/bin/lua5.1 tests/playtest/test_onboarding.lua .
python3 tests/unit/test_reference.py
python3 tests/unit/test_thermal_reference.py
python3 tests/unit/test_thermal_catalog.py
python3 tests/unit/test_thermal_survival.py
python3 scripts/thermal_catalog.py check-generated
python3 scripts/thermal_model.py check
python3 scripts/thermal_survival.py check
if [[ "${1:-}" == "--integration" ]]; then python3 tests/integration/run.py; fi
