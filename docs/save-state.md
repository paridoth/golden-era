# Saved-state validation, migration and repair

New machines use node metadata schema **2**. The simulation, direct processing,
automated transfer and player inventory/digging callbacks validate before changing
gameplay state. Invalid machines display `Paused: <reason>` and retain original
metadata and inventories; only diagnostics, infotext and formspec text change.
Valid neighbors continue running. A paused node remains in graph adjacency, so
pausing does not provide electrical or ownership isolation.

## Schema 2

- `schema` is 2 and `profile` is exactly `legacy` or `revelation`.
- `energy`, `work`, `burn`, `water`, `fuel_rf`, `water_rf` all exist as finite
  integers. Raw metadata agrees with engine integer getters; missing, fractional,
  overflowing and nonnumeric values pause.
- Energy/work/burn/water are nonnegative. Only producers store burn; only
  processors store work. Energy cannot exceed the profile-specific capacity.
- A `revelation` Dynamo has no legacy burn counter. Its water is 0..4000 mB,
  fuel credit -39..24000 RF and water credit -39..25000 RF. Negative remainders
  are deliberate debt from integer-tick conversion and survive refills/restarts.
- Legacy machines and non-producers require all three water/credit fields to be
  zero. Unknown profiles and future/missing schemas pause.

RF capacities differ by profile. Legacy values remain generator 32000, buffer
100000 and processors 8000. Revelation basic values are 40000, 2000000 and 20000.
Only valid completed-state upgrades can switch profiles; current target capacities
are larger and stored RF/items are retained.

## Known schema-1 migration

Schema 1 contains energy/work/burn and the original fixed-rate job format. Before
migration, all original numeric bounds, legacy capacities and job/inventory
relationships are checked. Invalid originals pause without migration or data
normalization. A valid machine receives profile `legacy`, zero water/credits and
bucket input/output slots; original energy, work, burn, job bytes and inventory
contents are unchanged. The schema-2 marker is written last, with no yield.
Interrupted preparation can repeat the same zero initialization while schema 1
remains the marker. This is not a forced-crash transaction journal.

Legacy machines keep their prior fixture behavior, including the existing
operator setting semantics. A burn-tick counter is not guessed into new RF credit:
its historical generation rate was never stored. The old pending job retains its
saved cost, rate and output. Unknown schemas are never automatically migrated.

After burn/work reach zero and the job is empty, an allowed player may explicitly
switch to the Revelation model using its formspec button. Stored RF, unlit fuel
and items remain; no fuel/water credit is granted. Protection and busy-state
checks reject the switch. This upgrade control does not repair malformed data.

## Saved jobs

Zero work requires an empty job. Positive work requires a job matching the reserved
input stack, with work strictly below cost. Missing jobs never substitute today's
recipe for already-paid work. Jobs use `core.deserialize(encoded, true)`, are at
most 4096 bytes and reject unknown fields and unsupported schemas.

The original job contains exactly `input`, `output`, `cost`, `rate`. It retains its
fixed processing rate, even across configuration changes and outer-state migration.
Primary-only dynamic jobs use `schema=2` and `rate_mode="buffer"`, and belong
to the Revelation profile. New iron jobs use schema 3, adding `secondary_output`,
`secondary_chance` (1..100) and `secondary_roll` (1..100). They require a secondary
slot and preserve their saved chance decision across blocking/restarts. This mode selects the current pinned basic buffer ramp; cost/output are
saved at job start. Its version semantics must be preserved during any later
parameter/schema transition.

Cost and saved rate are finite positive metadata-range integers. Outputs are plain
registered item names with an optional positive count fitting one native stack;
parser truncation, wear/NBT payloads and unknown items are rejected. Inputs remain
reserved until completion. Output-capacity preflight and commit never yield.
Schema 3 is a job version; machine metadata remains schema 2. Older jobs retain
their saved outputs and do not acquire a new secondary result.

## Repair boundary

The game does not delete jobs, reset balances or rewrite unknown schemas to make
bad data run. A paused machine requires trusted repair from known-good state.
Stop the server cleanly and back up the entire world directory before repairing
real persisted data. Recover the schema, numeric balances, saved job and matching
reserved inventory together; today's recipe cannot reconstruct original paid work.
If original state cannot be established, keep it paused until an explicit recovery
decision is made.

After a valid repair, diagnostics clear and processing resumes without free RF or
refunded work. Engine tests cover repair of a legacy job at 200/4000 work with
3800 RF, plus schema-2 invalid fields/jobs, clean restarts, legacy migration and
protected/busy upgrades. These checks do not authenticate privileged metadata,
sandbox hostile Lua, implement unknown-schema recovery or provide forced-crash
atomicity across inventory/mapblock writes.

## Item-side configuration

[Item-side controls](item-sides.md) use an optional version-1 port record alongside
metadata schema 2. Missing records preserve existing routing until explicit
opt-in. Present records require six valid modes, a disabled horizontal panel face
and a valid output toggle. Invalid records pause without inventory/RF changes.
Panel rotation and mode changes preserve saved jobs and paid work.

## Packed machines

[Relocation](relocation.md) keeps a complete validated snapshot in world mod storage
under a one-use token. The package item alone does not contain its contents.
Backups must include all world databases. Clean packed/restored restarts are
tested; cross-database forced-crash atomicity is not provided. A new placer owns
the restored machine for subsequent automation/protection checks.
