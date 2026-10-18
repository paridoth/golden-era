# Golden Era design pathway

## Goal and reference decision

Build a native Luanti game that reproduces the selected FTB Revelation 3.7.0
experience: interconnected technology, tools, automation, storage, magic and
exploration. Use the actual pack's versioned inputs and observed behavior as
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

Produce a reviewed behavior specification and a small supported data mapping,
then adapt the native modules. Add parity checks against the reference, including
input/output probabilities and resource balances. Preserve existing saves or
provide an explicit tested migration when state models change. Current fixture
rates/recipes stay provisional until their replacements have evidence.

## 3. Graphically playable survival and multiplayer slice

Play from gathering materials through crafting and operating the first factory.
Check recipes, formspecs, orientation/side configuration, clear status, machine
relocation/discharge and recovery. Exercise actual player inventory/crafting
callbacks and multiple clients, including contention and protection boundaries.
Keep targeted automation alongside these real gameplay checks. The existing
restart, chunk-lifecycle and corrupt-state suite is supporting infrastructure.

## 4. Extend connected systems incrementally

Use the exact selected generations: Tinkers' Construct 2 smeltery/casting/tools;
AE2 rv6 storage and crafting networks; Thaumcraft 6 scanning, knowledge/research,
casting and infusion. Establish their native data/state contracts before broad
content expansion. Other pack systems, including Refined Storage, Astral Sorcery,
Botania, Blood Magic 2 and additional industry/exploration, require explicit
coverage priorities rather than an assumption that every JAR is already scoped
for the first release. Witchery is outside the selected manifest.

## 5. Reliability, performance and release readiness

Measure realistic networks and contention as systems grow. Design schema
migrations and forced-crash recovery before transactional content expands.
Validate terrain/exploration and long-running worlds. Finish original visuals/
sound and inherited-media provenance before preparing a public distribution.
Keep reproducible source/config pins, automated checks, native gameplay tests
and documented limitations together.

The initial Thermal specification and bounded import are recorded. Ten native
crafting patterns now replace the first three machine shortcuts; their material
representatives are explicit and still lack tin/silver survival acquisition. The next
concrete deliverable is the resolved first-loop data/side mapping and a tested
native state migration, then a graphical factory session. Further
infrastructure work should address risks exposed by that milestone.
