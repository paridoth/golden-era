#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tools/ci-evidence
./scripts/setup.sh 2>&1 | tee tools/ci-evidence/setup.log
./scripts/test.sh --integration 2>&1 | tee tools/ci-evidence/tests.log
python3 scripts/setup-playtest.py --no-fetch 2>&1 | tee tools/ci-evidence/playtest-assembly.log
python3 tests/playtest/run.py 2>&1 | tee tools/ci-evidence/playtest.log
python3 tests/survival/run.py 2>&1 | tee tools/ci-evidence/survival.log
python3 tests/automation/run.py 2>&1 | tee tools/ci-evidence/automation.log
python3 tests/linux/test_save_guard.py 2>&1 | tee tools/ci-evidence/launcher-save-guard.log
