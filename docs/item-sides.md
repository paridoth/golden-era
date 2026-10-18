# Native item sides and routing

New Revelation-profile Pulverizers and powered furnaces have six configurable
item faces. The pinned `TilePulverizer` and `TileFurnace` classes provide slot
groups, mode types and default faces; CoFHCore `SideConfig` and
`TileReconfigurable`, plus `TileMachineBase`, supply the access/front rules.
Exact class hashes and method anchors are in
[the runtime review](../references/thermal-runtime-review.json) and
[crafting review](../references/thermal-crafting-review.json). The generated
runtime table is checked against these reviewed inputs.

Faces use the source order: down, up, north, south, west, east. A new node's panel
faces south. Pulverizer defaults: byproduct below, input above, primary on other
faces, with the panel disabled. Furnace defaults: input below/above, output on
other faces, with the panel disabled. Change the furnace's west face to input
for the original eastward Pulverizer-to-furnace fixture.

Each face button cycles through its machine's supported modes. Pulverizer modes
are Off, In, Main, By, Out (both outputs), All and I/O. Furnace modes are Off,
In, Out, All and I/O. All allows insertion into input and extraction from all
slots; I/O extracts outputs only. Input reserved by paid work cannot be pulled
in either mode. The panel cannot be enabled. Rotating the panel clears the new
panel face and retains other face settings, inventory and RF.

Auto output starts On and can be disabled. Enabled machines try adjacent
supported processors and ordinary Mineclonia chests, using both endpoint face
rules and protection checks. Primary and byproduct slots route separately.
The native ejector selects one of six directions and primary, byproduct or
unreserved input, pulling from the machine behind it into an ordinary chest
in front. Locked/double chests and arbitrary external inventories are unsupported.
This is a native transport adapter: transfer cadence, automatic-output defaults,
duct behavior, filters and original Thermal Dynamics parity are not established.
Item face rules do not control RF connections.

Existing legacy and pre-port schema-2 layouts keep their previous routing.
An existing Revelation-profile processor offers an explicit Enable button to
adopt source defaults. No saved job, RF or inventory is rewritten. Configured
nodes save six mode digits, panel face, configuration version and output toggle;
invalid configurations pause before simulation or inventory writes. Ejector
settings also persist and malformed settings pause without resetting them.
Protection checks apply to all configuration callbacks.

The two new engine phases verify mode access, split output routing, destination
input denial, output toggle, panel rotation, reserved-input locks, vertical
byproduct ejection, protection, exact SQLite configuration persistence, explicit
old-layout opt-in and six malformed configurations. The full regression suite
also exercises neighboring factories; native fixtures occupy a separate area so
new all-face routing cannot send their dust to another test's chest.
