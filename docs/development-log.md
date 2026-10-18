# Development log

## 2026-10-16 — previous machine (recorded handoff)

Built a six-mod factory slice on Mineclonia using a project-local Luanti server.
The preserved evidence reports 12 passing unit tests and three real engine
processes exercising processing, clean SQLite restart and automatic scheduling.
Root documentation, license files and CI were missing at interruption. These
old-machine results are not destination verification.

## 2026-10-18 — destination restore

Verified the migration archive SHA-256 and all 37 original source-manifest
entries before changing files. Restored beneath the dedicated workspace as
`golden-era-luanti/`. Destination: Linux Mint 22.3 (noble), x86_64, GCC/G++ 13.3.
All required commands were available; no sudo, system package installs, service
changes, firewall edits or public exposure were needed.

Completed the complete unmodified `scripts/setup.sh` path with the transferred
upstream sources and ten hash-verified cached Debian packages. This regenerates
local tools, CMake build products and runtime symlinks at the relocated path,
which contains spaces. The build exited 0; all 12 unit tests and all three engine phases passed.
Exact output and scope limits are preserved in `test-results.md` and
`docs/evidence/2026-10-18/`.

Added project README, architecture/history/compatibility/fidelity/license
records, full GPL and CC0 texts, texture provenance and a CI workflow. The
historical release announcement was checked directly; no launch manifest was
recovered, and no gameplay defaults were promoted from provisional status.
The original handoff and source hashes remain unchanged as migration evidence.

The CI entrypoint repeats setup and unit/engine tests. Its hosted workflow is
prepared for a future GitHub remote; no hosted CI run has been executed. It
preserves exact dependency versions and fails when those versions cannot be
obtained. Dependencies and source caches are optional accelerators, not a
substitute for verification.

Git author supplied by the user: Josh <paridoth@gmail.com>, scoped to this
repository. Baseline staging excludes upstream checkouts, tools, runtime,
worlds and credentials. Original and destination test evidence is intentionally
tracked through narrow log exceptions.
