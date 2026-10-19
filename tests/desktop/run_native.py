#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise real native inventory actions through an SDL virtual controller.

Uses only a dedicated authenticated Xvfb display, a disposable smoke game/world,
and the opt-in client. Never connects to the user's desktop or playtest world.
"""
import argparse
import json
import os
from pathlib import Path
import secrets
import shlex
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]

MOD = r'''
local state = {ready = false, closed = false, actions = {}}
local function save(player)
    local inv = player:get_inventory()
    state.src = inv:get_stack("src", 1):get_count()
    state.dst = inv:get_stack("dst", 1):get_count()
    local file = assert(io.open(core.get_worldpath() .. "/controller-state.json", "w"))
    file:write(core.write_json(state))
    file:close()
end
core.register_craftitem("controller_smoke:ingot", {description = "Controller test ingot",
    inventory_image = "unknown_item.png", stack_max = 99})
local form = "formspec_version[4]size[8,5,true]position[0,0]anchor[0,0]padding[0,0]no_prepend[]" ..
    "label[0.5,0.5;Controller native inventory test]" ..
    "list[current_player;src;1,1;1,1;]list[current_player;dst;3,1;1,1;]" ..
    "listring[current_player;src]listring[current_player;dst]" ..
    "button[1,3;3,1;confirm;Controller confirm]" ..
    "button_key[4,3;3,1;binding;GAMEPAD_BUTTON_0]"
core.register_on_joinplayer(function(player)
    player:set_physics_override({speed = 0, gravity = 0})
    player:set_pos({x=0,y=0,z=0})
    local inv = player:get_inventory()
    inv:set_size("src", 1); inv:set_size("dst", 1)
    inv:set_stack("src", 1, "controller_smoke:ingot 8")
    player:set_inventory_formspec(form)
    core.after(1, function()
        core.show_formspec(player:get_player_name(), "controller_smoke:test", form)
        state.ready = true
        save(player)
    end)
end)
core.register_on_player_inventory_action(function(player, action, inventory, info)
    state.actions[#state.actions + 1] = action
    save(player)
end)
core.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "controller_smoke:test" then
        if fields.quit then state.closed = true end
        if fields.confirm then state.confirmed = true end
        if fields.binding then state.bound = fields.binding end
        save(player)
    elseif formname == "" then
        if fields.confirm then state.inventory_confirmed = true end
        if fields.quit then state.inventory_closed = true end
        save(player)
    end
end)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--client", type=Path, default=ROOT / "runtime/desktop-controller/engine/bin/luanti")
    parser.add_argument("--display", default=":98")
    args = parser.parse_args()
    if args.display in (":0", ":97") or not args.display.startswith(":") or not args.display[1:].isdigit():
        parser.error("Use an isolated numbered display such as :98")
    if Path("/tmp/.X11-unix/X" + args.display[1:]).exists():
        raise SystemExit("Refusing to connect to an existing X display")
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="controller-native-", dir=base))
    print("Native controller evidence:", work, flush=True)
    game = work / "games/controller_smoke"
    mod = game / "mods/controller_smoke"
    mod.mkdir(parents=True)
    (game / "game.conf").write_text("title = Disposable controller smoke game\n")
    (mod / "mod.conf").write_text("name = controller_smoke\n")
    (mod / "init.lua").write_text(MOD)
    world = work / "world"
    world.mkdir()
    (world / "world.mt").write_text("gameid = controller_smoke\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n")
    config = work / "client.conf"
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    config.write_text(f"bind_address = 127.0.0.1\nport = {port}\nserver_announce = false\n"
                      "screen_w = 800\nscreen_h = 600\nfullscreen = false\nvsync = false\nfps_max = 60\n"
                      "mg_name = singlenode\nenable_damage = false\ncreative_mode = false\n"
                      "gui_scaling = 1\ndisplay_density_factor = 1\nviewing_range = 20\n"
                      "enable_sound = false\nshow_screenshots = false\n")
    commands, acks = work / "commands", work / "acks"
    commands.touch()
    acks.touch()
    shim = work / "virtual_gamepad.so"
    sdl = shlex.split(subprocess.check_output(["pkg-config", "--cflags", "--libs", "sdl2"], text=True))
    subprocess.run(["cc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-shared", "-fPIC",
                    str(ROOT / "tests/desktop/virtual_gamepad.c"), "-o", str(shim), "-ldl"] + sdl, check=True)
    auth = work / "Xauthority"
    auth.touch()
    subprocess.run(["xauth", "-f", auth, "add", args.display, ".", secrets.token_hex(16)], check=True)
    env = os.environ.copy()
    env.update(DISPLAY=args.display, XAUTHORITY=str(auth), LIBGL_ALWAYS_SOFTWARE="1", SDL_VIDEODRIVER="x11")
    env["LD_LIBRARY_PATH"] = ":".join(str(ROOT / part) for part in
        ("tools/client-root/usr/lib/x86_64-linux-gnu", "tools/root/usr/lib/x86_64-linux-gnu",
         "tools/gui-root/usr/lib/x86_64-linux-gnu"))
    xlog = (work / "xvfb.log").open("w")
    xserver = subprocess.Popen([str(ROOT / "tools/gui-root/usr/bin/Xvfb"), args.display,
                               "-screen", "0", "1280x900x24", "-nolisten", "tcp", "-auth", str(auth)],
                              env=env, stdout=xlog, stderr=subprocess.STDOUT)
    client = None
    output = (work / "client-output.log").open("w")
    sequence = 0

    def wait(predicate, label, seconds=10):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if predicate():
                return
            if client is not None and client.poll() is not None:
                raise AssertionError("Client exited while waiting for " + label)
            if xserver.poll() is not None:
                raise AssertionError("Xvfb exited; see " + str(work / "xvfb.log"))
            time.sleep(0.05)
        raise AssertionError("Timeout waiting for " + label)

    def command(text):
        nonlocal sequence
        sequence += 1
        with commands.open("a") as target:
            target.write(text + "\n")
        wait(lambda: f"{sequence} {text}\n" in acks.read_text(), "SDL command " + text)

    def click(button):
        command(f"button {button} 1")
        time.sleep(0.12)
        command(f"button {button} 0")
        time.sleep(0.12)

    def state():
        path = world / "controller-state.json"
        try:
            return json.loads(path.read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

    def counts(src, dst):
        wait(lambda: (state().get("src"), state().get("dst")) == (src, dst),
             f"native inventory src={src}, dst={dst}")
        print("PASS: native inventory", src, dst, flush=True)

    try:
        wait(lambda: Path("/tmp/.X11-unix/X" + args.display[1:]).exists(), "Xvfb startup")
        # glibc splits LD_PRELOAD on spaces even inside an absolute filename.
        # Load from the disposable cwd instead of modifying the engine's bin dir.
        env.update(LD_PRELOAD="./virtual_gamepad.so", GE_CONTROLLER_COMMANDS=str(commands), GE_CONTROLLER_ACKS=str(acks),
                   LUANTI_GAME_PATH=str(work / "games"))
        client = subprocess.Popen([str(args.client.resolve()), "--go", "--gameid", "controller_smoke",
                                   "--world", str(world), "--config", str(config), "--name", "ControllerTester",
                                   "--port", str(port),
                                   "--logfile", str(work / "client.log")],
                                  env=env, cwd=work, stdout=output, stderr=subprocess.STDOUT)
        wait(lambda: state().get("ready"), "fresh player formspec", seconds=40)
        command("focus")
        time.sleep(0.3)
        command("mouse 79 79")
        time.sleep(0.3)
        # A picks up all eight; a real virtual-controller axis moves to slot two.
        click(0)
        command("axis 0 20000")
        time.sleep(0.90)
        command("axis 0 0")
        time.sleep(0.2)
        click(0)
        counts(0, 8)
        # X picks up half, D-pad returns to source, X places one twice, A the rest.
        click(2)
        command("button 13 1")
        time.sleep(0.60)
        command("button 13 0")
        time.sleep(0.2)
        click(2)
        counts(1, 7)
        click(2)
        counts(2, 6)
        click(0)
        counts(4, 4)
        # Y uses the actual upstream Shift-click/listring transfer.
        click(3)
        counts(0, 8)
        command("button 14 1")
        time.sleep(0.30)
        command("button 14 0")
        command("button 12 1")
        time.sleep(0.60)
        command("button 12 0")
        time.sleep(0.2)
        click(0)
        wait(lambda: state().get("confirmed"), "A activating a native GUI button")
        # Controller clicks can start native key capture; raw gamepad events must
        # still reach that field instead of being converted into inventory clicks.
        command("mouse 291 185")
        time.sleep(0.2)
        click(0)
        click(2)
        wait(lambda: state().get("bound") == "GAMEPAD_BUTTON_2", "raw controller key rebinding")
        from PIL import ImageGrab
        old_auth = os.environ.get("XAUTHORITY")
        try:
            os.environ["XAUTHORITY"] = str(auth)
            ImageGrab.grab(xdisplay=args.display).save(work / "controller-inventory.png")
        finally:
            if old_auth is None:
                os.environ.pop("XAUTHORITY", None)
            else:
                os.environ["XAUTHORITY"] = old_auth
        click(1)
        wait(lambda: state().get("closed"), "B/Escape closing the formspec")
        # Native world Y opens the player's own inventory form after B closes
        # the server form. A must work immediately in the newly created menu.
        click(3)
        time.sleep(0.5)
        command("mouse 132 185")
        time.sleep(0.2)
        click(0)
        wait(lambda: state().get("inventory_confirmed"), "world Y/inventory A transition")
        click(1)
        wait(lambda: state().get("inventory_closed"), "B closing player inventory")
        print("PASS: GUI button, raw rebinding, B close, world Y reopen and A/B inventory transition", flush=True)
        command("quit")
        client.wait(timeout=15)
        if client.returncode != 0:
            raise AssertionError("Unexpected client exit code " + str(client.returncode))
        (work / "RESULT.json").write_text(json.dumps({"result": "pass", "state": state(),
            "scope": "Custom Linux client, real SDL virtual gamepad and native inventory actions; no physical hardware test."}, indent=2) + "\n")
    finally:
        for process in (client, xserver):
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        output.close()
        xlog.close()


if __name__ == "__main__":
    main()
