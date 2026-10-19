# Native storage regression

Run `python3 tests/storage/test_patch.py`, then `python3 tests/storage/run.py`.
The engine test uses port **30214**, isolated worlds under ignored `runtime/tests/`,
and the exact pinned stock engine. `--keep-world` preserves its disposable fixture
for investigation. It neither opens nor modifies a player world.

The runner compares two fresh games: untouched Drawers at `5c8aa86` and the
reviewed copied-source compatibility repairs. Each game runs twice, with an actual
engine process restart. The baseline deliberately asserts known losses and catches
its real Mineclonia explosion failure. Its one expected warning names the missing
`default` global. Repaired runs require no errors or warnings.

Coverage:

- All registered Drawers recipes resolve through the engine with concrete pinned
  Mineclonia ingredients, including native wood/stick/drawer groups.
- Native controller deposit preflight/commit conserve distinct item types. A
  five-node network measures five neighborhood scans per call in the baseline;
  warm repaired calls measure zero. Missing trim, reconnection, a new four-slot
  drawer, removed/respawned visuals, actual Mesecons MVPS controller movement,
  and a deliberately stale saved cache verify invalidation. A moved controller's
  restored metadata cannot reach disconnected old drawers; neither can a
  reloaded stale cache.
- Native upgrades change a single drawer's 64-stack-item capacity through
  2,304 → 4,608 → 6,912 → 11,520. Removing all upgrades from 5,000 iron leaves
  2,304 stored and **2,696 in actual bounded item entities**. The native pickup
  API recovers those entities; front interactions retrieve the rest. The repaired
  total is exactly 5,000, with no fabricated inventory credits.
- Native type lock, single/stack retrieval and protection checks retain their
  behavior. Metadata-bearing payloads and unstackable tools remain unsupported;
  worn stackable payloads are refused instead of losing wear.
- Native Mineclonia piston pushing respects Drawers' existing immobility policy.
  The baseline moves a 130-coal drawer, restores full metadata over an empty
  visual, then erases those 130 on the next insertion. The repaired drawer stays
  in place and all 130 stored plus one offered coal remain retrievable.
- Actual `core.dig_node` with an engine dummy digger, and native drawer digging
  with a full-inventory sneaking fake actor, preserve all 130 coal, the capacity
  upgrade and the drawer. The baseline loses those automatic spills.
- Actual `mcl_explosions.explode` reaches the ordinary drawer dig path and the
  controller blast callback. The repaired controller emits its worn tool with
  metadata intact, emits itself, removes its node, honors no-drop blasts, and
  accounts for an adjacent native barrel's 13 gold.

These are source-based device fixtures and detached inventories, not a survival
playthrough or a real PlayerRef inventory test. The controller's native synchronous
tube interface is exercised directly; production timers/ABMs are not manually
ticked. Real tube entities, clocked injectors and autocrafting into drawers have
their separate coverage in `tests/automation/`.
