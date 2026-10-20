# Machine state button regression

Run `python3 tests/machine-state/test_patch.py` for the fast checked-copy tests.
They execute the actual copied Lua helper under three enumeration orders and
check full, toggle-only, signal-only and empty supported sets, invalid saved IDs,
timer wake counts, source drift, repeatability and upstream isolation.

Run `python3 tests/machine-state/run.py` for the pinned native server comparison
on port 30238. Each variant gets a disposable SQLite world and two processes.
Baseline restores only the copied `machine.lua` to pinned Elepower c37fe7b;
baseline PASS reproduces the unreachable-state bug and is not release acceptance.
Repaired acceptance requires all native IDs in order and wraparound.

Fresh stock planter, harvester and generator start at their native default 0.
The observer invokes their registered `cyclestate` callbacks as an unprotected
named actor and waits for normal timers to refresh the actual formspec tooltips.
It checks each selected ID and the unchanged native `state_enabled` semantics,
then verifies selected IDs/tooltips after a real process restart. It does not
manufacture the stock state sequence or invoke machine timer callbacks directly.

Separately labeled stock registration-API controls exercise supported subsets,
explicitly seeded unknown saved IDs, empty sets and original callback delegation.
A temporary fixture protection predicate verifies that the native protected-field
guard still refuses state changes, timer wakes and delegated callbacks.

The runner rejects every engine error or warning and requires one exact
`ERA MACHINE STATE PASS: CHECKPOINT:` / `COMPLETE:` marker per process.
Logs are written to ignored `runtime/tests/machine-state-smoke.log`.
This checks server callbacks; an actual graphical button click is a separate test.
