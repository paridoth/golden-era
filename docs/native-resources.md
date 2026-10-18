# Native basic RF and water model

Newly constructed machines use schema 2 and the `revelation` profile. The native
implementation now uses sourced basic fuel, water, RF-buffer, processing-cost and
rate-selection rules. This is a supported resource model, not complete Thermal
Expansion or full-pack parity. [Saved-state rules](save-state.md) describe the
preserved legacy profile and explicit upgrade path.

## Operating the first factory

Put coal or charcoal in a new Dynamo's fuel slot and an ordinary Mineclonia water
bucket in its Water slot. Leave the Empty slot free for the returned empty bucket.
One bucket supplies 1000 mB to a 4000 mB tank. Bucket loading preflights the tank
and empty-bucket destination before changing either inventory or water balance.
A dry Dynamo does not consume a new fuel item. A blocked bucket return or a full
tank does not consume the supplied water bucket.

Coal supplies 24000 RF of fuel credit; charcoal supplies 16000. Conversion drains
100 mB at a time, adding 25000 RF of **water credit**. Every generated RF debits
both independent credits. Small negative remainders carry into the next batch;
they must not be clamped to zero. Unconverted water, credits and bucket inventories
persist together across clean restarts. Water credit is not additional fuel RF.

Basic capacities are 40000 RF for the Dynamo, 20000 for each processor and 2000000
for the buffer. Default processing costs are 4000 RF for one iron ore to two dust
and 1500 RF for each dust to one ingot. Mineclonia raw iron remains an explicit
native compatibility input; it did not exist in Minecraft 1.12.2. New iron jobs now include the [persisted nickel byproduct](byproducts.md);
older in-flight jobs retain their primary-only semantics.

Maximum rates are 40 RF/t for generation and 20 RF/t for processing. Rates depend
on each machine's own stored RF using the sourced integer ramps in the static
specification. The dynamic-rate job saves its cost/output and rate-mode version;
existing four-field jobs retain their original fixed rate. Legacy fixture setting
overrides affect legacy machines; they do not silently change this pinned basic
model. Upgrades/augments are not implemented.

An active full Dynamo can still spend fuel and water at its minimum 4 RF/t rate.
RF storage clamps the excess, which is dissipated. Full storage therefore does
not imply fuel consumption pauses. A generator without usable fuel or water
cannot begin another conversion. This differs from the older fixture generator.

## Evidence and compilation

`scripts/thermal_model.py` compiles the basic parameters from
`references/revelation-3.7.0-thermal.json` into the native
`mods/era_thermal/reference.lua`. The ordinary test entrypoint checks this
reproducibly without original downloads. Lua arithmetic lives in `model.lua`.

```sh
python3 scripts/thermal_model.py check
python3 scripts/thermal_model.py fetch-sources
python3 scripts/thermal_model.py check-sources
```

The source commands separately verify reviewed TE/RedstoneFlux class hashes
against the locked original JARs. `thermal-runtime-review.json` anchors storage
clamping and dynamo debit/update behavior, supplementing the existing static
review. No Java classes or pack scripts are loaded or executed.

## Native scheduling boundary

The shared 20-Hz scheduler still uses abstract connected components. It generates,
fills buffers, dispatches processor RF, processes jobs, saves metadata and finally
moves items. Native donors share a per-tick output budget across targets; buffers
use the sourced 1000 RF/t receive/send bounds. Native processor input and generator
output use provisional 80 RF/t graph limits. Available processor RF is shared
among non-full native processors to prevent the first large buffer from trapping
all fuel energy. Legacy processors retain the older allocation behavior.

This allocation is a native policy, not a reconstruction of Thermal Dynamics
duct routing. Per-face controls, physical cable throughput, redstone control,
startup delays and the original active/post-tick refill ordering are not yet
reproduced. Conversion amounts and carried debt are supported; exact item-consume
or refill timing at a tick boundary can differ. No original-runtime parity
observation has been claimed.

## Migration and remaining work

Valid schema-1 machines migrate automatically to schema 2 with profile `legacy`.
Their RF, work, burn, serialized job and items remain unchanged; water and native
credits start at zero. They continue the prior fixture rules until explicitly
upgraded. This avoids inventing an RF value for old burn ticks whose historical
rate may not have been recorded.

Once its current burn/job finishes, an allowed player can press **Use Revelation
model**. Stored RF, unlit fuel and inventories are preserved. No water or native
fuel credit is granted. A protected or busy machine rejects the switch. Invalid
machines pause and cannot use the upgrade button as a reset or repair path.

The engine fixture now demonstrates two ores -> four primary ingots spending
14000 RF from one 24000-RF coal, retaining 10000 stored RF, 900 mB unconverted
water and 1000 RF water credit after one bucket. It repeats across SQLite
restarts and checks charcoal, signed debt, full-buffer dissipation, bucket
preflight, old burn/jobs, upgrades and malformed state.

Item-side controls, directional ejection, basic cell crafting and tin/silver/lead
acquisition are implemented. Remaining work includes ducts, fluid pipes, augments,
graphical/player inventory tests and original-runtime parity
observations. Filled machines/credits cannot be dug normally. [Factory Wrench relocation](relocation.md)
preserves their resources and jobs without a drain/reset. The state code does not supply forced-crash atomicity.
