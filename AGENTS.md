Keep work inside this repository. Never install system packages or change unrelated services.
Use Lua 5.1 syntax. Server simulation must not yield between inventory preflight and commit.
Run scripts/test.sh before committing. Run engine integration after runtime changes.
Record historical claims with exact version evidence; otherwise mark provisional.
Do not add assets without provenance and license. Keep generated worlds and downloads untracked.

Current reference: FTB Revelation 3.7.0 (Minecraft 1.12.2), selected by the user on 2026-10-18. See references/revelation-3.7.0.lock.json and docs/historical-reference.md. The Direwolf20 target in the immutable migration HANDOFF.md is superseded.
Use the actual pinned pack/configs as primary evidence. Keep downloaded pack originals under ignored references/cache/; never execute them as part of reference import or bundle them into the game.

Current delivery priority (user direction, 2026-10-18): get a playable existing-mod Luanti pack working quickly, then play and add features incrementally. Prefer stock mods/forks and native equivalents; exact Revelation parity is deferred. The active playtest is scripts/play-playtest.py and docs/playtest.md. Keep the earlier custom Thermal slice and its worlds available separately. Avoid expanding custom frameworks when an existing mod can supply the gameplay.

Current platform scope (user direction, 2026-10-19): Windows and Linux only. The Shield/Android prototype was explicitly canceled. Continue useful work autonomously across packaging, survival progression and desktop usability when another component is blocked. Preserve the frozen 0.1.0 artifacts and saved worlds. Optional custom-engine controller work stays separate from the stock-engine release until verified.
