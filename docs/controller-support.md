# Experimental desktop controller menus

The normal Windows release uses the official Luanti 5.17.0 engine. Its SDL
controller bindings cover movement and world actions, but it does not translate
gamepad events into menu cursor input. Changing key bindings cannot supply that
missing behavior. The optional prototype here requires a separately built engine;
it does not change the normal installer or launchers.

The prototype uses SDL's normalized gamepad axis/button events in the shared
`GUIModalMenu`, so the same cursor can operate main-menu formspecs, player
inventories, crafting, and machine forms. It sends ordinary upstream mouse/key
events; inventory counts, splitting, quick-transfer and recipe rules stay native.
No machine mod forms are rewritten. World control bindings remain upstream.

## Menu controls

The letters below refer to Xbox-style labels; the physical positions also work
when a controller uses different labels.

| Input | Menu action |
| --- | --- |
| Left stick | Move the cursor; lower tilt gives finer movement |
| D-pad | Move the cursor more slowly |
| A / bottom face button | Left-click: pick up a stack, then click to place it |
| X / left face button | Right-click: pick up half a stack or place one item |
| Y / top face button | Shift-click: transfer a stack through the form's inventory ring |
| B / right face button, Back, or Start | Escape/back |
| Left/right shoulder | Scroll up/down over the hovered control |

Clicks are complete press/release pairs; holding A does not drag. Duplicate down
events are suppressed. A mouse or touchscreen immediately takes over. Hiding a
modal menu clears held stick/D-pad and button state, so a release delivered to
another menu cannot leave an input stuck. Native controller rebinding remains
available while a key field captures input.

## Build and run on this Linux development host

The existing local graphical development dependencies must already be prepared
with `scripts/build-client.py`. This prototype installs no system packages.

```sh
python3 integrations/desktop/build-client.py
python3 integrations/desktop/play-controller.py
```

Only tracked sources/assets are copied from the pinned, clean Luanti revision
into `runtime/desktop-controller/engine`; ignored caches, client databases and
worlds are excluded. The builder checks all copied tracked files and rejects
unexpected extra source files. Four files are changed there: three upstream
GUI files plus the added cursor header. The patch checks exact original hashes,
preflights every destination, refuses Git/upstream trees and external symlinks,
and is idempotent. When intentionally changing the patch templates, create a
fresh isolated candidate tree; mismatched existing edits are rejected.

The optional play launcher creates a separate persistent controller test world
and preserves its settings. The existing workshop/survival worlds are separate.
This host build follows the existing development client: sound and HTTP support
are disabled. It is not a portable Linux distribution or a Windows engine build.

## Validation

```sh
python3 tests/desktop/test_gamepad.py
python3 tests/desktop/run_native.py
```

The first command compiles the actual cursor policy with C++17 and UBSan, testing
deadzone, frame rate/resolution scaling, precision, diagonal and viewport bounds,
duplicate button suppression, modal/mouse handoff and SDL controller-ID changes.
It also verifies patch idempotency, whole-patch preflight, dirty-file rejection,
upstream/Git protection and symlink protection.

The native test needs the repository-local Xvfb under `tools/gui-root` and uses
its own authenticated `:98` display, a disposable smoke game/world, and an SDL
virtual game controller. It verifies actual server inventory counts after A
pick/place with stick movement, X half-stack/place-one with D-pad movement,
Y quick-transfer, A activating a GUI button, raw controller rebinding, and
B closing / world Y reopening the player's inventory. Logs, state and a screenshot remain
under the printed `runtime/tests/controller-native-*` directory. It refuses the
user desktop and any already running display.

On 2026-10-19 the isolated Linux build, six policy/patch tests (including compiled
UBSan checks), and the native virtual-controller test passed. The same native
test against the unmodified Linux development engine failed at the first A/stick/A
transfer as expected: the original inventory stayed at 8/0. See the exact hashes
and results in `docs/evidence/2026-10-19/controller-menus.json`.

Physical controller behavior, the complete Mineclonia/Elepower UI range, and a custom
Windows engine remain unverified. Text entry still needs a keyboard. Keep the
prototype optional until actual play confirms those interactions.
