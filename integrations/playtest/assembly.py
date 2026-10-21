"""Assemble the isolated stock-mod playtest without changing the main game."""
import importlib.util
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[2]
GAME_ID = "golden_era_playtest"
DEFAULT_DESTINATION = ROOT / "runtime/playtest/games" / GAME_ID
SOURCES = (
    "luanti", "mineclonia", "pipeworks", "basic_materials", "xcompat", "fakelib",
    "mesecons", "elepower", "fluid_lib", "drawers",
    "logistica", "mcl_extra_structures", "travelnet", "magicalities",
)
ALIAS_BEFORE = 'local game_alias = {\n    mineclone2 = "mineclonia",\n}\n'
ALIAS_AFTER = 'local game_alias = {\n    mineclone2 = "mineclonia",\n    golden_era_playtest = "mineclonia",\n}\n'


class AssemblyError(Exception):
    pass


def _git(source, *arguments):
    return subprocess.check_output(
        ["git", "-C", str(source), *arguments], text=True, stderr=subprocess.STDOUT
    ).strip()


def _build_info(root):
    """Record the source state once, without timestamps or parent-repo guesses."""
    version = json.loads((root / "packaging/playtest/release.json").read_text())["version"]
    if not isinstance(version, str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?", version):
        raise AssemblyError("Invalid playtest release version")
    info = {"version": version, "revision": None, "dirty": None, "source": "source_snapshot"}
    # An exported source tree can live inside another Git checkout. Only the
    # project's own .git directory/file may supply its build identity.
    if not (root / ".git").exists():
        return info
    try:
        if pathlib.Path(_git(root, "rev-parse", "--show-toplevel")).resolve() != root.resolve():
            return info
        revision = _git(root, "rev-parse", "HEAD")
        if not re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", revision):
            return info
        dirty = bool(_git(root, "status", "--porcelain", "--untracked-files=all"))
    except (OSError, subprocess.CalledProcessError):
        return info
    info.update(revision=revision, dirty=dirty, source="git")
    return info


def verify_sources(fetch=False):
    """Fetch missing sources only; reject existing modified or different revisions."""
    lock = json.loads((ROOT / "upstream.lock.json").read_text())
    selected = {}
    for name in SOURCES:
        if name not in lock:
            raise AssemblyError("Missing source pin in upstream.lock.json: " + name)
        spec = lock[name]
        source = ROOT / "upstream" / name
        if not source.exists():
            if not fetch:
                raise AssemblyError("Missing pinned checkout (fetch disabled): " + name)
            source.parent.mkdir(parents=True, exist_ok=True)
            # Build a complete checkout beside its final name before publishing it.
            with tempfile.TemporaryDirectory(prefix=".fetch-" + name + "-", dir=source.parent) as temporary:
                checkout = pathlib.Path(temporary) / "checkout"
                subprocess.run(["git", "init", str(checkout)], check=True, stdout=subprocess.DEVNULL)
                subprocess.run(["git", "-C", str(checkout), "remote", "add", "origin", spec["url"]], check=True)
                subprocess.run(["git", "-C", str(checkout), "fetch", "--depth", "1", "origin", spec["commit"]], check=True)
                subprocess.run(["git", "-C", str(checkout), "checkout", "--detach", "FETCH_HEAD"], check=True)
                checkout.rename(source)
        if not (source / ".git").exists():
            raise AssemblyError("Source is not a local Git checkout: " + name)
        if pathlib.Path(_git(source, "rev-parse", "--show-toplevel")).resolve() != source.resolve():
            raise AssemblyError("Unexpected source checkout root: " + name)
        if _git(source, "rev-parse", "HEAD") != spec["commit"]:
            raise AssemblyError("Source revision mismatch: " + name)
        if _git(source, "status", "--porcelain", "--untracked-files=all"):
            raise AssemblyError("Dirty source checkout: " + name)
        selected[name] = spec
    return selected


def _patch_module(name, path):
    location = ROOT / "integrations/playtest" / (name + ".py")
    if not location.is_file():
        raise AssemblyError("Missing reviewed compatibility helper: " + str(location))
    spec = importlib.util.spec_from_file_location("playtest_patch_" + name, location)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    result = module.apply(path)
    if not isinstance(result, list) or not all(isinstance(item, str) for item in result):
        raise AssemblyError("Patch helper must return a list of descriptions: " + name)
    return result


def _destination(path):
    destination = pathlib.Path(path).expanduser().absolute()
    if destination.name != GAME_ID:
        raise AssemblyError("Destination directory must be named " + GAME_ID)
    if destination.is_symlink():
        raise AssemblyError("Refusing to replace a symlink destination")
    destination = destination.resolve()
    allowed = (ROOT / "runtime/playtest", ROOT / "runtime/tests")
    if not any(destination.is_relative_to(base.resolve()) for base in allowed):
        raise AssemblyError("Destination must be inside runtime/playtest or runtime/tests")
    if destination.exists() and not destination.is_dir():
        raise AssemblyError("Destination already exists as a non-directory")
    return destination


def _populate(game, selected):
    mods = game / "mods"
    mods.mkdir(parents=True)
    mineclonia = ROOT / "upstream/mineclonia"
    for source in sorted((mineclonia / "mods").iterdir()):
        (mods / source.name).symlink_to(source, target_is_directory=source.is_dir())
    # Stock modpacks stay whole, including their documentation, assets and licenses.
    for name in ("basic_materials", "fakelib"):
        if (mods / name).exists():
            raise AssemblyError("Duplicate Mineclonia/modpack name: " + name)
        (mods / name).symlink_to(ROOT / "upstream" / name, target_is_directory=True)
    for name in ("xcompat", "elepower", "fluid_lib", "mesecons", "drawers", "pipeworks",
                 "logistica", "mcl_extra_structures", "travelnet", "magicalities"):
        if (mods / name).exists():
            raise AssemblyError("Duplicate Mineclonia/modpack name: " + name)
        # Newer mods ship developer test worlds/fixtures; they are not game content.
        ignored = (".git", "test") if name in ("logistica", "travelnet") else (".git",)
        shutil.copytree(ROOT / "upstream" / name, mods / name, ignore=shutil.ignore_patterns(*ignored))
    source = mods / "xcompat/src/gameid.lua"
    original = source.read_text()
    if original.count(ALIAS_BEFORE) != 1:
        raise AssemblyError("Pinned xcompat alias table changed; review compatibility patch")
    source.write_text(original.replace(ALIAS_BEFORE, ALIAS_AFTER, 1))
    patches = ['xcompat/src/gameid.lua: golden_era_playtest = "mineclonia"']
    patches.extend(_patch_module("elepower", mods / "elepower"))
    patches.extend(_patch_module("fluid_lib", mods / "fluid_lib"))
    patches.extend(_patch_module("mesecons", mods / "mesecons"))
    patches.extend(_patch_module("drawers", mods / "drawers"))
    patches.extend(_patch_module("pipeworks", mods / "pipeworks"))
    patches.extend(_patch_module("logistica", mods / "logistica"))
    patches.extend(_patch_module("magicalities", mods / "magicalities"))
    starter = ROOT / "integrations/playtest/mod"
    if not (starter / "mod.conf").is_file():
        raise AssemblyError("Missing era_playtest integration mod")
    (mods / "era_playtest").symlink_to(starter, target_is_directory=True)
    for name in ("menu", "minetest.conf", "settingtypes.txt", "LICENSE.txt", "LEGAL.md", "CREDITS.md", "README.md"):
        source = mineclonia / name
        if source.is_dir():
            shutil.copytree(source, game / name)
        else:
            shutil.copy2(source, game / name)
    original = (mineclonia / "game.conf").read_text()
    if original.count("title = Mineclonia") != 1:
        raise AssemblyError("Pinned Mineclonia game title changed")
    (game / "game.conf").write_text(original.replace("title = Mineclonia", "title = Golden Era: stock mod playtest", 1))
    # Stored outside the symlinked development mod; each assembled game keeps
    # its own identity, which the runtime reads without invoking Git.
    (game / "build-info.json").write_text(json.dumps(_build_info(ROOT), indent=2) + "\n")
    manifest = {
        "gameid": GAME_ID,
        "purpose": "Isolated Mineclonia + stock Elepower/Pipeworks/Drawers/Mesecons/Logistica/Travelnet/Magicalities playtest",
        "sources": selected,
        "runtime_copy_patches": patches,
        "custom_mods": ["era_playtest"],
        "build_info": "build-info.json",
    }
    (game / "playtest-sources.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def build_game(destination=DEFAULT_DESTINATION, fetch=True):
    """Rebuild a disposable assembly; preserve an existing game if preparation fails."""
    destination = _destination(destination)
    selected = verify_sources(fetch=fetch)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".assemble-playtest-", dir=destination.parent) as temporary:
        work = pathlib.Path(temporary)
        staged = work / GAME_ID
        manifest = _populate(staged, selected)
        previous = work / "previous"
        if destination.exists():
            destination.rename(previous)
        try:
            staged.rename(destination)
        except OSError:
            if previous.exists():
                previous.rename(destination)
            raise
    return manifest
