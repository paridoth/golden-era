# Architecture

## Modules and boundaries

| Mod | Responsibility |
| --- | --- |
| `era_core` | machine registration, metadata, formspecs, tracking, inventory callbacks and pure integer ledger |
| `era_compat_mcl` | native item names and startup assertions |
| `era_materials` | iron dust and native cooking recipe |
| `era_energy` | six-face graph, cached components and authoritative simulation |
| `era_thermal` | provisional rates, generators/buffers/processors and recipe jobs |
| `era_transport` | protected one-item transfer, fixed +X routing and chest allowlist |

No global `default` shim is provided. The adapter uses Mineclonia APIs and item
IDs directly. Public shared functions are `era.register_machine`,
`era.register_recipe`, `era.track`, `era.invalidate`, `era.state`, `era.save`,
`era.networks`, `era.step`, `era.process`, `era.move_one`, `era.machine_ready`,
`era.resolve_recipe`, and `era.valid_integer`; pure arithmetic
and connected-component helpers live in `era.ledger`.

## Simulation

A globalstep accumulates elapsed time and executes 0.05-second simulation steps.
Backlog is capped at 0.25 seconds, so lag may slow production. Each step rebuilds
components only when tracking epoch or active-node signature changes. Members
are sorted deterministically. Producers generate; generators fill buffers;
processors draw from producers/buffers; processing and metadata saves follow;
item transport runs last.

RF is an integer balance, conserved by transfers and consumed exactly by
processing. This is abstract adjacency: cable rate applies per donor/buffer
pair, not as a physical edge-flow limit. Processor input has one shared budget
across donors. Buffers do not exchange directly. Sorted consumer order has no
fairness guarantee and can starve later consumers.

Inventories are checked for valid input and complete output capacity before RF
is spent. Input remains reserved until completion and cannot be removed while
work is pending. Output insertion and internal player inventory moves are
denied. Preflight and commit execute synchronously without yielding. These
properties do not provide crash-atomic transactions across mapblocks.

## Save state

Node metadata stores `energy`, `work`, `burn`, and `schema` (currently 1).
An in-flight `job` serializes input name, result, total RF cost and processing
rate. Integration covers clean SQLite restarts and changing the
recipe cost/rate/yield across a restart: the saved job retains its old values,
the next input uses the changed values, and completed results survive another
restart back to defaults. Validation now pauses malformed jobs, invalid integer
balances and unsupported schemas before gameplay mutations. RF transfers,
processing, automated item moves, player inventory callbacks and digging honor
that pause. Healthy neighboring machines remain usable. No corrupt balance,
job or schema is silently reset; only diagnostic `fault`, infotext and formspec
fields are updated. See [saved-state validation and repair](save-state.md) for
the precise schema-1 contract and recovery boundary. Unknown-schema migration
and forced-crash recovery remain unimplemented.

Loaded positions are tracked; unavailable/ignore nodes are pruned. A load-time
LBM re-registers machines, cables and ejectors. Offline generation is absent.
The older restart fixture explicitly re-tracks nodes. A separate lifecycle
fixture now exercises actual engine-timed mapblock eviction and engine-driven
LBM reactivation across the x=15/16 boundary, with no manual re-tracking or
tracking-table edits. Keeping only the generator side active splits the network;
reactivating the processor side restores connectivity. Full eviction/reload
preserves pending jobs, RF, burn and inventories without offline catch-up.

LBMs run when mapblocks become **active**, not merely when loaded into memory.
The lifecycle test uses transient forceload/release calls to control activation
without a graphical client, shortened test-only eviction/activation intervals,
and explicit simulation steps. Real player travel/proximity and broader network
topologies remain separate validation targets.

## Interaction and protection

Player inventory and digging callbacks check `core.is_protected`. Automated
transfer checks source and destination for the stored actor. Ordinary native
chests are explicitly allowlisted; arbitrary third-party callbacks are not
invoked. RF connectivity itself has no ownership isolation. Real concurrent
players and third-party protection systems have not been tested.

Machines ignore explosions and are piston-immovable to avoid untested state
loss. Machines with items, energy, work or remaining burn cannot be dug. All
machines currently show input/output/fuel slots even where a slot is unused.

## Extension order

Resolve historical references, extend schema migration and chunk-lifecycle
coverage, and test multiplayer contention, crash recovery and scale/fairness before
expanding content. Smelteries, storage/crafting networks and research/magic are
future milestones in the handoff, not implemented subsystems.
