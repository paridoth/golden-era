# Elepower playtest integration

The disposable playtest uses Elepower `c37fe7bc3fc52a05e03507ca35cba2c8e5b3e330`
and fluid_lib `9b52f6eb7b6fd7fa81f2e923e1d3bd5950ec9762`. Their upstream
notices and assets remain in the copied modpacks. These Python helpers patch
only assembled copies, check exact expected source text and tolerate repeated
application. Stock machine behavior, power rates, content and progression are
retained; this is an equivalent technology pack rather than Thermal parity.

`elepower.apply(path)` corrects Mineclonia item references after xcompat's
generic fallbacks, keeps Elepower's own tin, bronze and silver, and routes its
existing machine recipe registration into `mcl_craftguide`. The upstream
Elepower Tome remains available as well. Player inventory forms and hoppers
use the existing upstream Mineclonia support. The fusion reactor fluid input
port receives the same final-remainder correction as generic Node IO buffers.
The upstream diagrams-only `elepower_documentation` directory receives a
`mod.conf` declaration to avoid the deprecated unnamed-mod fallback.

`fluid_lib.apply(path)` fixes two related fluid conservation issues: partial
buffer insertion must return the leftover quantity, and multi-buffer Node IO
insertion must return the final remainder rather than adding each intermediate
remainder. Runtime smoke checks should include a nearly full tank and two
buffers, not just empty single tanks.

Focused checks run the patched upstream Lua functions: `test_fluid.lua` checks
partial, full, mixed-fluid and multi-buffer conservation; `test_elepower.lua`
checks single/multiple output recipes through the Mineclonia guide API shape.
Both accept the assembled modpack directory as their sole argument and run
with the repository's `tools/root/usr/bin/lua5.1`. Copy patch application and
reapplication were also checked. Full game interoperability is verified by
the playtest engine smoke, rather than these focused checks alone.

`mesecons.apply(path)` fixes iteration over Mineclonia's named dye-color table,
restoring colored component recipes, and uses `core.override_item` when marking
existing piston stopper nodes. This avoids re-registering an existing item
definition, including the engine's `ignore` node.

Starter node names: `elepower_machines:generator`, `power_cell`, `pulverizer`,
`furnace`, `coal_alloy_furnace`, and `elepower_dynamics:conduit`. The generator
takes coal in `src`; processors use `src` and `dst`. Energy metadata is
`storage`. Stock coal generation is 16 EpU per one-second timer step;
pulverizer and furnace use 32 EpU per step. The stock network uses an ABM and
force-loads connected providers. This playtest keeps those upstream choices.
