# Saved-state validation and repair

Machines use node metadata schema **1**. The running simulation, direct processing
entrypoint, automated transfers and player inventory/digging callbacks check the
machine before changing its gameplay state. Invalid machines display
`Paused: <reason>` in infotext and formspec text. The diagnostic is derived
state; stored RF, work, burn, schema, job and inventories are retained.

A paused machine does not generate, donate, receive or process RF, and does not
send or accept items. Player inventory changes and digging are denied. Its node
still participates in physical graph adjacency, so valid neighboring machines
can continue exchanging RF through the component. Pausing is not an electrical
isolation or ownership feature.

## Schema 1 contract

- `schema` must represent 1. Missing, older and future schemas pause; no automatic
  migration or downgrade is attempted.
- `energy`, `work` and `burn` must exist as finite nonnegative integers in
  0..2147483647. Raw numeric metadata must agree with the engine integer getter;
  fractional, overflowing or nonnumeric strings are not silently coerced.
- RF cannot exceed machine capacity. Only generators may store remaining burn;
  only processors may store pending work.
- For processors, zero work requires an empty `job`. Positive work requires a saved job whose
  input matches the reserved input stack. Missing jobs never fall back to the
  current recipe while work is pending.
- Saved jobs retain the existing Lua serialization format, decoded with
  `core.deserialize(encoded, true)`. Records are limited to 4096 bytes and must
  be a table with exactly the supported keys: `input`, `output`, `cost`, `rate`.
- Cost and rate must be finite positive integers within the same metadata
  integer range; accumulated work must remain strictly below total cost.
- Outputs are plain item names with an optional positive integer count. The
  item must resolve to a registered item; count must survive engine parsing
  exactly and fit one native stack. Wear/metadata payloads and unknown extra
  fields are unsupported by schema 1.

Valid existing schema-1 jobs remain supported, including jobs with old costs,
rates or yields after a configuration change. Their output is validated as
saved, rather than replaced with the current recipe. These checks do not
establish the historical correctness of any mechanic.

## Repair boundary

The game deliberately does not delete jobs, zero balances or rewrite schemas to
make a bad machine run. A paused machine needs an explicit trusted repair from
known-good state. There is no player reset button or automated repair tool yet.

For a real world, stop the server cleanly and back up the entire world directory
before repairing persisted data. Recover the correct schema, integer balances,
job fields and matching reserved inventory together from a known-good backup
or other authoritative record. Guessing a job from today's recipe can change
already-paid work. If its original state cannot be established, keep it paused
until an explicit recovery decision is made.

After a valid repair, normal validation clears the diagnostic and processing
resumes; it does not grant free RF or return already-spent work. Integration
checks this with a job at 200/4000 RF and 3800 stored RF: one input is consumed,
two dust are added, RF and work become zero, and a further restart cannot repeat
that output.

This validation addresses malformed records and numeric bounds. It does not
authenticate metadata, provide arbitrary hostile-Lua sandboxing, migrate unknown
schemas, or make mapblock/inventory writes atomic across a forced crash. Trusted
mods or administrative tools can still deliberately write plausible values.
