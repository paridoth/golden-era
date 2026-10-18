# Architecture

Gameplay reference: FTB Revelation 3.7.0 (Minecraft 1.12.2), selected on
2026-10-18. The runtime remains native Luanti/Mineclonia. See
[the reference workflow](../references/README.md) and [roadmap](roadmap.md).

## Modules and boundaries

| Mod | Responsibility |
| --- | --- |
| `era_core` | machine registration, metadata, formspecs, tracking, inventory callbacks and pure integer ledger |
| `era_compat_mcl` | native item names and startup assertions |
| `era_materials` | generated native material/component crafting catalog |
| `era_energy` | six-face graph, cached components and authoritative simulation |
| `era_thermal` | sourced basic resource model, preserved legacy rates and recipe jobs |
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

RF transfers conserve integer balances; processing and fuel/water conversion
use profile-specific arithmetic. Full native Dynamo storage can dissipate minimum
generation while consuming credits. Graph dispatch is a native approximation:
native donors share output budgets, and available processor RF is shared to avoid
stranding all generation in the first large buffer. Legacy nodes retain the old
allocation. These are not physical per-edge duct limits; buffers do not exchange
directly. Native idle/active start timing and side control remain incomplete.

Inventories are checked for valid input and complete output capacity before RF
is spent. Input remains reserved until completion and cannot be removed while
work is pending. Output insertion and internal player inventory moves are
denied. Preflight and commit execute synchronously without yielding. These
properties do not provide crash-atomic transactions across mapblocks.

## Save state

Schema 2 stores energy/work/burn, profile, water and signed fuel/water credits.
Valid schema 1 migrates to a preserved legacy profile without changing its original
balances, jobs or items. An explicit protected upgrade switches an idle legacy
machine to the basic Revelation model. New jobs snapshot cost/output and a versioned
buffer-rate mode; older jobs retain fixed rates. Malformed records pause before
gameplay mutations. See [saved-state rules](save-state.md) and
[native resources](native-resources.md). Unknown-schema migration and forced-crash
atomicity remain unimplemented.

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
loss. Machines with items, energy, work, remaining burn, water or credits cannot be dug. All
machines currently show input/output/fuel slots even where a slot is unused.

## Extension order

The selected reference inventory/configs are now pinned. Next, specify and
import the supported Thermal factory behavior from those exact inputs, then
validate it in graphical survival and multiplayer sessions. Extend migrations,
crash recovery and performance checks around those systems as they grow.
Tinkers 2, AE2 rv6 and Thaumcraft 6 are future native branches; the earlier
handoff's 1.7.10 generation choices are historical. No reference importer
executes Java mods, pack scripts or installers.
