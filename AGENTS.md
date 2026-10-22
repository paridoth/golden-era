Keep work inside this repository. Never install system packages or change unrelated services.
Use Lua 5.1 syntax. Server simulation must not yield between inventory preflight and commit.
Run scripts/test.sh before committing. Run engine integration after runtime changes.
Record historical claims with exact version evidence; otherwise mark provisional.
Do not add assets without provenance and license. Keep generated worlds and downloads untracked.

Current reference: FTB Revelation 3.7.0 (Minecraft 1.12.2), selected by the user on 2026-10-18. See references/revelation-3.7.0.lock.json and docs/historical-reference.md. The Direwolf20 target in the immutable migration HANDOFF.md is superseded.
Use the actual pinned pack/configs as primary evidence. Keep downloaded pack originals under ignored references/cache/; never execute them as part of reference import or bundle them into the game.

Current delivery priority (user direction, 2026-10-18): get a playable existing-mod Luanti pack working quickly, then play and add features incrementally. Prefer stock mods/forks and native equivalents; exact Revelation parity is deferred. The active playtest is scripts/play-playtest.py and docs/playtest.md. Keep the earlier custom Thermal slice and its worlds available separately. Avoid expanding custom frameworks when an existing mod can supply the gameplay.

Current platform scope (user direction, 2026-10-19): Windows and Linux only. The Shield/Android prototype was explicitly canceled. Continue useful work autonomously across packaging, survival progression and desktop usability when another component is blocked. Preserve the frozen 0.1.0, 0.1.1, 0.1.2, 0.1.3, 0.1.4, 0.1.5, 0.1.6, 0.1.7 and 0.1.8 artifacts and saved worlds. Optional custom-engine controller work stays separate from the stock-engine release until verified.

Desktop 0.1.8 source is frozen at d9a4410eb1c68168dcd3610e154845b5da5d068a. Its artifact hashes and executed checks are recorded in docs/releases/0.1.8.json; earlier releases retain their own records. Future production changes require a new version before packaging; do not rebuild over frozen artifacts. Use an explicit new output path for isolated reproduction experiments.
The two older diagnostic archives are reserved separately in docs/releases/archived-diagnostics.json; they are retained history, not recommended tester downloads.
