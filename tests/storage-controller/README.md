# Native controller automation

Run `python3 tests/storage-controller/run.py`. The fixture uses port **30219**,
fresh ignored worlds under `runtime/tests/`, the pinned stock engine and the
current assembled game. `--keep-world` preserves its disposable fixture. Player
worlds and the separate storage-conservation evidence are untouched.

The line is a native barrel → stackwise filter-injector → two ordinary tubes →
drawer controller. A native Mesecons blinking control pulses the injector through
its ordinary timer. Connected trim leads to an iron drawer with a native iron
capacity upgrade, a separate locked copper drawer, and a four-compartment drawer.
The filter has two native ghost selectors; these configure routing without adding
physical materials.

Every poll accounts for the exact source inventory, all stored drawer counts and
every native `pipeworks:tubed_item` payload. Loose item entities fail the check.
Both motion directions must be observed while a packet is blocked. Native clock
state changes prove the timer is running; the test never calls an injector
effector, clock timer, tube step, or controller insertion callback itself.

| Checkpoint | Upgraded iron drawer | First iron compartment | Second iron compartment | Copper drawer | Iron in flight |
| --- | ---: | ---: | ---: | ---: | ---: |
| First capacity block | 4,608 | 0 | 0 | 17 | 5 |
| Distribution enabled | 4,608 | 5 | 0 | 17 | 0 |
| Second capacity block, saved | 4,608 | 576 | 0 | 20 | 9 |
| New engine process | 4,608 | 576 | 0 | 20 | 9 |
| Final delivery | 4,608 | 576 | 16 | 24 | 0 |

The first eight-iron packet fills three free spaces and returns its five-item
remainder to the tube network. A separate six-copper packet still reaches its
matching locked drawer. Distribution defaults off, so an empty compartment is not
used for this existing iron type. Enabling the native controller checkbox releases
the packet into the first empty compartment.

For the second capacity test, the fixture adds 571 iron through the native drawer
API to fill that compartment, disables distribution again, and feeds nine iron
plus three copper through the actual clocked line. The clock is stopped with its
normal right-click control. An engine shutdown/restart must preserve the nine-item
in-flight packet, inventories, upgrade, type locks, ghost selectors, distribution
setting and stopped timer. The packet must resume moving while still blocked.
Enabling distribution releases it; restarting the clock delivers another seven
iron and four copper. Final totals are exactly **5,200 iron and 24 copper**.

The expected behavior comes from pinned Pipeworks `5dfd572` and Drawers `5c8aa86`,
with the reviewed copied-source compatibility fixes. The injector removes source
items before downstream capacity is known (`filter-injector.lua:221–355`). Tube
routing consults receiver capacity and reverses or drops failed routes according
to native topology/settings (`item_transport.lua:115–175, 375–425`). Two connected
tubes give this fixture a native bouncing path under the default
`drop_on_routing_fail=false`; an open end can instead emit loose items. Controller
preflight/deposit/distribution behavior is in `drawers/lua/controller.lua:215–273,
380–422`.

This is a device fixture, not a gathered-material survival playthrough or a real
PlayerRef test. A small actor configures native interfaces and fixture prefills;
all tested deliveries and backpressure use stock timers and Pipeworks' native Lua
tube entities advancing in normal globalsteps. No additional bundled gameplay
mods or production changes are introduced by this harness.
