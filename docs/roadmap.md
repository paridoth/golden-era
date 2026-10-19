# Golden Era design pathway

## Active delivery priority — playable existing-mod pack

The user's 2026-10-18 direction is to get a playable pack quickly using available
Luanti mods/forks, then play, fix issues and add features. The active build now
assembles Mineclonia with full Elepower, Pipeworks, fluid_lib, Storage Drawers and
Mesecons. A supplied workshop makes the first industry/logistics loop immediately
available; see [playtest](playtest.md). Native equivalents and stock balance are
accepted for this first build. Recreating every infrastructure layer or requiring
exact Revelation parity before play is no longer the critical path.

Next work should follow actual play feedback: broken or confusing interactions,
missing survival ingredients, useful pack recipe changes, and the next requested
storage/tools/magic/exploration feature. Reuse existing projects first. Keep a
small automated boot/industrial-flow regression and preserve working worlds.
The detailed reference/parity pathway below remains background for selective
future adaptations and the earlier custom prototype.

## Desktop playtest 0.1.1 — 2026-10-19

The active targets are Windows and Linux. The user explicitly canceled the
Shield/Android prototype and authorized continued autonomous work across useful
components. Frozen 0.1.0 artifacts remain available.

Version 0.1.1 adds a one-time workshop/survival choice, a first-factory guide and
six stock advancement triggers. Existing players keep their state. The survival
path grants no workshop tools/materials; the stock Elepower help book remains.
Operator/testing privileges are granted only in single-player workshop starts.
Steel-block and wireless dye compatibility fixes preserve stock recipe costs.

Windows EXE and Linux archive candidates are recorded in
[release metadata](releases/0.1.1.json). Linux uses an installed native Luanti or
the official Flatpak. Native crafting/resource acquisition, packaged factory
flow, real Linux onboarding/destination/restart checks and the exact Windows
PowerShell bootstrap have separate evidence and clearly stated limits. Human
survival pacing and native Windows startup remain to be played.

The next desktop update, 0.1.2, adds visible workshop loading, saved pending trips,
cancellation/retry and protection against stale travel callbacks. Real client
shutdown/restart checks preserve the trip and exact inventory, then keep the
player's new position after arrival. Launchers reject foreign, ambiguous and
orphaned saves before writing settings or metadata.

The stock Pipeworks autocrafter-to-drawer scenario is now verified: sixteen
conduits and all six returned spools survive output backpressure and a process
restart. The guide explains collecting returned spools separately. The next
feature priority still follows actual play feedback; these checks do not replace
a human survival session or a native Windows test.
The experimental [desktop controller engine](controller-support.md) is separate
from these stock-engine releases; physical controllers and a custom Windows
binary remain unverified.

Version 0.1.3 addresses native Drawers item loss and the controller's explosion
crash, with a baseline/repaired conservation and restart regression. It also
repairs controller caching while testing disconnected paths, and protects frozen
package outputs from replacement. Native storage recipes and controller deposit/
manual retrieval behavior are documented in the
[storage guide](../integrations/playtest/storage-notes.md). Further compatibility
work follows concrete stock-mod defects and player feedback.

Version 0.1.4 preserves the Pipeworks autocrafter's owned input/output stacks
through Mineclonia explosions and distinguishes newly constructed filter
previews from historical physical inventories. Its baseline/repaired regression
uses real explosions, both piston APIs, normal block activation and process
restart. All filter variants temporarily resist piston movement; mine, place
and reconfigure them to relocate. Existing unmarked filters retain native legacy
refunds because their ownership cannot reliably be inferred. See the
[Pipeworks findings](../integrations/playtest/pipeworks-notes.md) for the exact
old-save boundary and the source evidence.

## Goal and reference decision

Build a native Luanti game that reproduces the selected FTB Revelation 3.7.0
experience: interconnected technology, tools, automation, storage, magic and
exploration. Prefer assembling compatible existing Luanti mods with a focused
Revelation integration layer. Use the actual pack's versioned inputs and observed behavior as
primary evidence. The user's 2026-10-18 choice supersedes the earlier Direwolf20
1.7.10/TE4/Thaumcraft4 plan. Mineclonia remains the survival foundation, with
its differences from Minecraft 1.12.2 reviewed deliberately.

This is an independent implementation. Golden Era is still a working name.
No full-pack fidelity, unchanged-JAR compatibility or completed media audit has
been established.

## 1. Pin and inspect the actual pack — initial acquisition complete

The 1000-entry manifest is pinned; all 675 selected configs and four pack scripts
are cached and hash-verified. The first 15 Thermal config facts have source
hashes and line numbers. Exact mod builds are available in the lock/inventory.

The first [Thermal intermediate specification](thermal-factory-spec.md) now
imports selected embedded recipes/fuels and three literal crafting statements,
preserving metadata, groups and chances. Reviewed class hashes anchor water,
buffer/rate, furnace and tier rules. Next: resolve effective item groups/outputs,
complete crafting and side behavior, and validate the remaining semantics. Do not treat config
extraction as complete behavior extraction. Unknown fields/behaviors must be
reported rather than invented. Inspection tools should not execute pack code.
Any original-runtime export is a separate controlled operation.

## 2. One reference-driven Thermal factory loop

Prioritize the existing slice: Steam Dynamo, RF connections, storage, Pulverizer,
Redstone Furnace, item routing and ordinary storage. Determine exact recipes,
RF per operation, coal/fluid requirements, capacities, side controls and base
upgrade behavior from the pinned builds and effective pack scripts.

The first reviewed specification, native crafting catalog, basic RF/water model
and known-state migration are implemented. Persisted secondary outputs and native item-side controls are implemented.
Complete survival acquisition and storage crafting before graphical play. Add parity checks against the reference, including
input/output probabilities and resource balances. Preserve existing saves or
provide an explicit tested migration when state models change. Legacy fixture
rates stay preserved; remaining storage/transport recipes are provisional.

## 3. Reuse existing infrastructure before expanding the framework

The optional-mod reuse comparison is now the next engineering milestone, ahead
of more custom transport, power infrastructure, storage or tooling. Pipeworks
already supplies item networks, filters and routing; build and test a small
adapter to our machine contracts in an isolated Mineclonia-derived game first.
Compare Elepower's standalone buffered energy/fluid APIs and selected Technic
utilities before expanding our power implementation. Evaluate existing Storage
Drawers and Wrench implementations before building their equivalents. Use
Mineclonia's existing recipe guide for machine-recipe discovery.

Keep Revelation reference data, behavior specifications and regression tests
as the contract. Generic infrastructure may come from upstream projects, with
our code supplying recipes, RF/job rules and adapters where needed. An existing
mod's Mineclonia support does not establish compatibility with Golden Era's game
ID, materials, protection and saved jobs. See the source findings and concrete
acceptance scenario in [mod compatibility](mod-compatibility.md).

## 4. Graphically playable survival and multiplayer slice

Play from gathering materials through crafting and operating the first factory.
Check recipes, formspecs, orientation/side configuration, clear status, machine
relocation/discharge and recovery. Exercise actual player inventory/crafting
callbacks and multiple clients, including contention and protection boundaries.
Keep targeted automation alongside these real gameplay checks. The existing
restart, chunk-lifecycle and corrupt-state suite is supporting infrastructure.

## 5. Extend connected systems incrementally

Use the exact selected generations: Tinkers' Construct 2 smeltery/casting/tools;
AE2 rv6 storage and crafting networks; Thaumcraft 6 scanning, knowledge/research,
casting and infusion. Establish their native data/state contracts before broad
content expansion. Other pack systems, including Refined Storage, Astral Sorcery,
Botania, Blood Magic 2 and additional industry/exploration, require explicit
coverage priorities rather than an assumption that every JAR is already scoped
for the first release. Witchery is outside the selected manifest.

## 6. Reliability, performance and release readiness

Measure realistic networks and contention as systems grow. Design schema
migrations and forced-crash recovery before transactional content expands.
Validate terrain/exploration and long-running worlds. Finish original visuals/
sound and inherited-media provenance before preparing a public distribution.
Keep reproducible source/config pins, automated checks, native gameplay tests
and documented limitations together.

The initial specification, sixteen native crafting patterns and basic RF/water model
are implemented. Schema-1 migration preserves legacy behavior with an explicit
upgrade path. Persisted nickel secondary outputs now have restart/overflow checks. Native item-side controls and directional ejection are implemented. Storage crafting and tin/silver/lead acquisition are implemented; next validate
the graphical survival session. The user confirmed four ingots after withdrawing
the corrected demo output. Native complete-state wrench relocation is implemented
with separate registry/restart checks. The user has now confirmed the wrench
interaction worked. Actual crafting, survival gathering and multiplayer remain
hands-on checks. The next development milestone is the reuse comparison above.
