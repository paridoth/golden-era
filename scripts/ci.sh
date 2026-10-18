#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p tools/ci-evidence
./scripts/setup.sh 2>&1 | tee tools/ci-evidence/setup.log
./scripts/test.sh --integration 2>&1 | tee tools/ci-evidence/tests.log
