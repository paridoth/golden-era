# Existing-mod playtest smoke

Run `python3 tests/playtest/run.py` from the repository after fetching the pinned
playtest sources. The runner verifies those pins and assembles a disposable
`golden_era_playtest` game and world under `runtime/tests/`. It uses loopback port
30202 and writes `runtime/tests/playtest-smoke.log`.

The real engine builds the same workshop offered to the player. Stock Elepower
power ABMs and node timers run normally; stock Mesecons clocks pulse the stock
Pipeworks filter-injectors. The check waits for two raw iron to become four iron
ingots in the output barrel. It also resolves and crafts selected machinery,
transport and storage recipes with registered ingredients and checks fluid
buffer fill, drain and overflow conservation.

The native check reads the assembly's build record, compares it with the loaded
version API, invokes `/packversion` and checks the workshop help's version label.
The response is recorded in the smoke log. Separate fast build-identity tests
cover clean, changed, untracked and exported source trees without using worlds.
Actual registered machine-field callbacks cycle the workshop generator and two
spare farm machines through all four states before returning to Always on. The
separate machine-state regression covers native tooltip refreshes, state subsets,
protection and saved IDs through restart.

Four mapblocks are temporarily force-loaded because this test has no connected
player. Production work is never advanced by directly invoking an ABM or machine
timer. The Lua test allows 150 seconds for the workshop and the runner allows
180 seconds for engine startup and completion. The temporary world is removed
after the run; ordinary game assemblies and play worlds are untouched.

This covers the starter factory's normal runtime flow. Graphical presentation,
player interaction, broader progression and restart behavior need their own
checks.
