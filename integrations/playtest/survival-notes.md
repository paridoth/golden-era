# Stock factory progression audit

Audited on 2026-10-19 against the Mineclonia and Elepower revisions in
`upstream.lock.json`. The active existing-mod pack needs no replacement early
machine recipes to reach its first electric factory.

The stock starting route is an ordinary furnace, Elepower Grindstone with Hand
Crank, then Coal-fired Alloy Furnace. The furnace smelts raw iron into iron and
smelts that iron again into Elepower's Low Carbon Steel. The unpowered grindstone
uses the same grinding recipes as the later Pulverizer. The coal alloy furnace
makes three brass ingots from two copper ingots and one silver ingot. Four brass
ingots in a cross make the brass gear used in a Machine Block.

Plastic is also available before electricity: six leaves craft two Oil Extract;
each extract smelts to Paraffin, then smelts again to Plastic Sheet. Native shears
collect leaves. Generator, conduits, Pulverizer and powered furnace can precede
the Power Cell. The cell needs later soldering/compressing products and must not
be presented as the bootstrap power source.

Blank PCB has an ingot-based recipe that needs no compressor. Four Copper Dust
and wheat seeds make Acidic Compound. Right-click water with the compound, then
right-click that acid with blank PCB. One acid source etches ten boards before
becoming water again. The alternative plate-based blank PCB recipe belongs
later in progression.

Two bounded compatibility repairs apply to disposable assembled Elepower copies:

- Map the existing native Steel Block into `ele.external.ing.steel_block` so
  mining, wireless and nuclear recipes retain their stock block ingredients.
- Use Elepower's game-specific red dye mapping for Wireless Control Chips;
  Mineclonia exposes `basecolor_red`, whereas the original hard-coded
  `color_red` group has no matching items in this pack.

No upstream checkout is changed. These repairs restore upstream ingredients;
they do not introduce new recipe costs or grant materials to players.

## Evidence and limits

`python3 tests/playtest/run.py` checks actual crafting outputs, stock steel-block
costs, the native ten-use PCB transformation, and the powered workshop's existing
two-raw-iron-to-four-ingot route. Its recipe reachability check derives fifteen
factory targets from ordinary survival materials and generated metal ores,
unlocking grinding, alloying, soldering and compression only when their required
stock machines are reachable. It checks dependencies rather than quantities,
travel time, or human usability. It assumes the listed vanilla materials,
including ordinary dyes, can be gathered through Mineclonia's survival systems.

`python3 tests/survival/run.py` separately generates v7 terrain with fixed seed
`8675309`. An iron-pick checkpoint actor mines real generated lead, tin, silver,
zinc, nickel, iron, copper and redstone, creates their normal dropped entities,
and acquires them through native item pickup. Those ore inputs feed stock
furnaces, the hand-cranked grindstone and a coal alloy furnace under normal server
timers. Native oak growth from a fixture sapling supplies leaves even when the
sample biome has no trees. The scenario confirms steel, plastic, manual iron
doubling and brass without invoking the supplied workshop or injecting power.

The actor uses a detached inventory, provided tools and stock device fixtures;
this is an acquisition/processing regression check, not a complete survival
playthrough or validation of controller/player-interface behavior. Human play
must still assess resource availability, recipe discovery, pacing and comfort.
The passing log is in `docs/evidence/2026-10-19/survival-smoke.log`.
