# Workshop loading and saved trips

Choosing the supplied workshop or using `/workshop` now immediately shows a
nonblocking loading message. Players can keep exploring while terrain loads;
they are moved automatically when the workshop is ready. The message explains
`/cancelworkshop`, which cancels the trip without moving the player or changing
their inventory. `/explore` also cancels a waiting workshop trip before returning
to the saved natural spawn. No percentage or fixed completion time is shown.

First generation previously took about 22 seconds in an isolated Linux GUI run.
The engine's terrain queue can take longer on another machine. The game waits
for actual terrain completion instead of assuming a fixed delay.

Disconnecting during preparation preserves the trip. The next login resumes it
and shows the loading message again. The original starter tools and privileges
are not granted again. First-arrival help still appears after the resumed trip.
Once arrival succeeds, subsequent logins keep the player's saved position.

If terrain generation or fixture construction fails, the HUD is removed and chat
explains `/workshop` to retry or `/cancelworkshop` to cancel. The retryable trip
remains saved until success or explicit cancellation. Remaining callbacks from
the failed/canceled request cannot move the player.

## Save compatibility and callback ordering

The existing `era_playtest_joined`, `era_playtest_start_mode` and
`era_playtest_surface` metadata keep their meanings. Two additional player fields
record only an outstanding workshop trip:

| Metadata | Meaning |
| --- | --- |
| `era_playtest_workshop_pending` | `1` while a trip is pending or awaiting a retry |
| `era_playtest_workshop_first` | `1` when first-arrival workshop help is still due |

Arrival or cancellation clears both fields. A returning 0.1.0/0.1.1 player without
the new pending marker is never automatically sent back to the workshop, even
if their original start mode was workshop. Existing worlds and inventories are
preserved. Shared workshop construction retains its existing `workshop_v1` guard.

Each connected session has an opaque identity and each travel request has its
own identity. Callbacks check both before building, teleporting, or clearing
pending state. A disconnect discards the session's HUD/request handles while
leaving saved metadata intact. A newer surface/workshop request invalidates the
earlier request. This also guards the scheduled continuation after the final
terrain callback, where cancellation or disconnect can happen before arrival.

`tests/playtest/test_onboarding.lua` executes the actual module and simulates
those asynchronous event orders without touching a native world save. It checks
pending resume, one-time kit and privilege grants, legacy positions, duplicate
requests and completions, cancellation, generation/queue/fixture failures and
retries, and stale callbacks from older sessions or earlier travel choices.

```sh
tools/root/usr/bin/lua5.1 tests/playtest/test_onboarding.lua .
scripts/test.sh
python3 tests/playtest/gui.py
python3 tests/playtest/trip_gui.py
```

The normal native GUI test checks real PlayerRef metadata/HUD behavior, actual
workshop arrival, and restart persistence in disposable worlds. Screenshots and
logs are written under `runtime/tests/onboarding-gui`.

The interrupted-trip test uses its own authenticated `:98` display and explicit
loopback port 30216. It actually clicks the workshop option, verifies a pending
trip and loading HUD, adds a seven-copper inventory fixture, and immediately
requests normal shutdown. The second process checks the saved pending marker
before the one-second resume timer, then waits for real workshop arrival. It
checks that the kit and copper counts remain unchanged, moves to a different
saved position, and starts a third process to verify there is no repeat warp.
Logs and native metadata/inventory snapshots remain in
`runtime/tests/workshop-trip`; the temporary world/game are removed by default.
Use `--keep-world` when a retained world is needed for diagnosis. A workshop that
finishes before the initial interruption window is reported as inconclusive.
No ordinary play world is used. The successful 0.1.2 three-session result and
inventory/metadata snapshots are retained under `docs/evidence/2026-10-19/` with
the `trip-0.1.2-` filename prefix.
