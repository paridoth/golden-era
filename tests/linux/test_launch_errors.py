#!/usr/bin/env python3
"""Exercise the current Linux launcher with local engine/dialog stubs, without ports."""
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "packaging/linux/templates/start.sh"
BASE = ROOT / "runtime/tests"

ENGINE = r'''import json,os,signal,subprocess,sys,time
from pathlib import Path
args=sys.argv[1:]
with open(os.environ['GE_TEST_CALLS'],'a') as f:
 f.write(json.dumps(args)+'\n')
if '--version' in args:
 print('Luanti 5.17.0 (launcher test stub)');sys.exit(0)
if os.environ.get('GE_TEST_FLATPAK')=='1' and args[0]=='info':sys.exit(0)
if os.environ.get('GE_TEST_FLATPAK')=='1' and args[0]=='enter':
 if os.environ.get('GE_TEST_ENTER_FAIL')=='1':sys.exit(1)
 assert args[1]==Path(os.environ['GE_TEST_INSTANCE']).read_text()
 assert '/.flatpak-info' in args[4] and '"$actual" = "$1"' in args[4]
 assert 'kill -TERM -1' in args[4]
 ready=Path(os.environ['GE_TEST_READY'])
 if not ready.exists():sys.exit(1)
 os.kill(int(ready.read_text()),signal.SIGTERM);sys.exit(0)
mode=os.environ.get('GE_TEST_MODE','success')
if os.environ.get('GE_TEST_FLATPAK')=='1':
 Path(os.environ['GE_TEST_MONITOR']).write_text(str(os.getpid()))
 time.sleep(float(os.environ.get('GE_TEST_ID_DELAY','0')))
 instance=str(os.getpid())+'123'
 Path(os.environ['GE_TEST_INSTANCE']).write_text(instance)
 fd=int(next(arg.split('=',1)[1] for arg in args if arg.startswith('--instance-id-fd=')))
 os.write(fd,instance.encode());os.close(fd)
 if mode=='wait':
  env=os.environ.copy();env['GE_TEST_FLATPAK']='0'
  child=subprocess.Popen([sys.executable,__file__,*args],env=env)
  sys.exit(child.wait())
if mode=='stdin':
 Path(os.environ['GE_TEST_STDIN']).write_text(sys.stdin.read());sys.exit(0)
if mode=='log':
 Path(args[args.index('--logfile')+1]).write_text('Current test client log\n')
if mode=='wait':
 def stop(signum,frame):
  Path(os.environ['GE_TEST_STOPPED']).write_text(str(signum));sys.exit(0)
 signal.signal(signal.SIGTERM,stop)
 Path(os.environ['GE_TEST_READY']).write_text(str(os.getpid()))
 while True:signal.pause()
if mode in ('fail','log'):
 print('Harmless test engine startup failure',file=sys.stderr);sys.exit(42)
'''


class LaunchErrors(unittest.TestCase):
    def setUp(self):
        BASE.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="launch errors with spaces ", dir=BASE)
        self.addCleanup(self.temporary.cleanup)
        self.work = Path(self.temporary.name)
        self.bundle = self.work / "game [qa] ' $ &"
        (self.bundle / "defaults").mkdir(parents=True)
        self.defaults = self.bundle / "defaults/playtest.conf"
        self.defaults.write_text("# packaged defaults\nviewing_range = 60\nkeymap_inventory = SYSTEM_SCANCODE_8\ngolden_era_settings = 2\n")
        self.launcher = self.bundle / "start.sh"
        shutil.copyfile(SOURCE, self.launcher)
        self.launcher.chmod(0o755)
        subprocess.run(["sh", "-n", str(self.launcher)], check=True)
        self.data = self.work / "save [qa] ' $ &"
        self.bin = self.work / "bin"
        self.bin.mkdir()
        # A closed command path keeps tests independent of installed engines and
        # GUI utilities. Everything else uses shell builtins or absolute Python.
        for name in ("dirname", "sed", "awk", "mkdir", "cat", "mktemp", "rm", "sleep"):
            (self.bin / name).symlink_to(shutil.which(name))
        self.engine = self.work / "engine stub"
        self.executable(self.engine, ENGINE)
        self.executable(self.bin / "flatpak", ENGINE)
        for name in ("luanti", "minetest"):
            self.executable(self.bin / name, "print('Luanti 5.16.0 (old test engine)')\n")
        self.dialogs = self.work / "dialogs.jsonl"
        self.dialog_stub = "import json,os,sys\nwith open(os.environ['GE_TEST_DIALOGS'],'a') as f:f.write(json.dumps(sys.argv[1:])+'\\n')\n"
        self.executable(self.bin / "zenity", self.dialog_stub)
        self.calls = self.work / "calls.jsonl"
        self.ready = self.work / "ready.pid"
        self.stopped = self.work / "stopped.txt"
        self.env = os.environ.copy()
        self.env.update(PATH=str(self.bin), GOLDEN_ERA_ENGINE=str(self.engine),
                        GOLDEN_ERA_DATA_DIR=str(self.data), DISPLAY="unused-test-display",
                        WAYLAND_DISPLAY="", GE_TEST_DIALOGS=str(self.dialogs),
                        GE_TEST_CALLS=str(self.calls), GE_TEST_READY=str(self.ready),
                        GE_TEST_STOPPED=str(self.stopped), GE_TEST_MODE="success",
                        GE_TEST_STDIN=str(self.work / "stdin.txt"),
                        GE_TEST_MONITOR=str(self.work / "monitor.pid"),
                        GE_TEST_INSTANCE=str(self.work / "instance.txt"))

    @staticmethod
    def executable(path, code):
        path.write_text("#!" + sys.executable + "\n" + code)
        path.chmod(0o755)

    def flatpak(self):
        self.env.pop("GOLDEN_ERA_ENGINE")
        self.env["GE_TEST_FLATPAK"] = "1"

    def launch(self, *args, input=None):
        return subprocess.run([str(self.launcher), *args], env=self.env, text=True,
                              input=input, capture_output=True, timeout=10)

    def dialog(self, result, text):
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(text, result.stderr)
        self.assertTrue(self.dialogs.exists(), result.stderr)
        dialogs = [json.loads(line) for line in self.dialogs.read_text().splitlines()]
        self.assertEqual(len(dialogs), 1)
        self.assertTrue(any(text in argument for argument in dialogs[0]), dialogs)

    def no_engine_launch(self):
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()] if self.calls.exists() else []
        self.assertFalse(any("--logfile" in call for call in calls), calls)

    def test_save_path_file_reports_initialization_error(self):
        self.data.write_bytes(b"keep existing file\x00\xff")
        result = self.launch()
        self.dialog(result, "Could not create the save folders")
        self.assertIn(str(self.data), result.stderr)
        self.assertIn("disk space", result.stderr)
        self.assertEqual(self.data.read_bytes(), b"keep existing file\x00\xff")
        self.no_engine_launch()

    def test_missing_defaults_reports_complete_archive_instruction(self):
        self.defaults.unlink()
        result = self.launch()
        self.dialog(result, "The game defaults are missing or unreadable")
        self.assertIn("Extract the complete game archive again", result.stderr)
        self.assertFalse(self.data.exists())
        self.no_engine_launch()

    def test_settings_directory_is_refused_without_copying_into_it(self):
        (self.data / "settings.conf").mkdir(parents=True)
        result = self.launch()
        self.dialog(result, "The settings path is not a readable settings file")
        self.assertEqual(list((self.data / "settings.conf").iterdir()), [])
        self.assertFalse((self.data / "worlds").exists())
        self.no_engine_launch()

    def test_dangling_settings_link_is_not_followed(self):
        self.data.mkdir()
        target = self.work / "must not be created.conf"
        (self.data / "settings.conf").symlink_to(target)
        result = self.launch()
        self.dialog(result, "The settings path is not a readable settings file")
        self.assertFalse(target.exists())
        self.assertTrue((self.data / "settings.conf").is_symlink())
        self.no_engine_launch()

    def broken_cat(self, world):
        real_cat = str((self.bin / "cat").resolve())
        (self.bin / "cat").unlink()
        # Simulate a write failure after shell redirection, including when run
        # as root. The actual shell's error branch must report the right file.
        code = ("import os,sys\n"
                "if bool(sys.argv[1:]) == " + str(not world) + ":\n"
                " print('Simulated write failure',file=sys.stderr);sys.exit(38)\n"
                "os.execv(" + repr(real_cat) + ", ['cat']+sys.argv[1:])\n")
        self.executable(self.bin / "cat", code)

    def test_settings_write_failure_is_reported(self):
        self.broken_cat(world=False)
        result = self.launch()
        self.dialog(result, "Could not create settings at")
        self.assertIn(str(self.data / "settings.conf"), result.stderr)
        self.no_engine_launch()

    def test_world_metadata_write_failure_is_reported(self):
        self.broken_cat(world=True)
        result = self.launch()
        self.dialog(result, "Could not create world metadata at")
        self.assertIn(str(self.data / "worlds/playtest/world.mt"), result.stderr)
        self.assertEqual((self.data / "settings.conf").read_bytes(), self.defaults.read_bytes())
        self.no_engine_launch()

    def test_foreign_save_refuses_before_defaults_engine_or_any_writes(self):
        world = self.data / "worlds/playtest"
        world.mkdir(parents=True)
        metadata = b"gameid = a_different_game\n"
        (world / "world.mt").write_bytes(metadata)
        self.defaults.unlink()
        before = {p.relative_to(self.data): (p.stat().st_mtime_ns, p.read_bytes() if p.is_file() else None)
                  for p in [self.data, *self.data.rglob("*")]}
        result = self.launch()
        self.dialog(result, "This save belongs to another game")
        after = {p.relative_to(self.data): (p.stat().st_mtime_ns, p.read_bytes() if p.is_file() else None)
                 for p in [self.data, *self.data.rglob("*")]}
        self.assertEqual(after, before)
        self.assertFalse(self.calls.exists())

    def test_existing_settings_and_world_are_preserved_without_defaults(self):
        world = self.data / "worlds/playtest"
        world.mkdir(parents=True)
        settings = b"# player settings\nviewing_range = 44\n"
        metadata = b"# saved world\ngameid = golden_era_playtest\n"
        (self.data / "settings.conf").write_bytes(settings)
        (world / "world.mt").write_bytes(metadata)
        self.defaults.unlink()
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.data / "settings.conf").read_bytes(), settings)
        self.assertEqual((world / "world.mt").read_bytes(), metadata)
        self.assertFalse(self.dialogs.exists())

    def test_old_settings_are_upgraded_once_for_lan_and_keys(self):
        settings = self.data / "settings.conf"
        self.data.mkdir()
        settings.write_bytes(b"# player settings\nbind_address = 127.0.0.1\nport = 30200\nviewing_range = 44\n")
        for attempt in ("first", "repeat"):
            result = self.launch()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(settings.read_text(), "# player settings\nviewing_range = 44\n"
                             "keymap_inventory = SYSTEM_SCANCODE_8\ngolden_era_settings = 2\n", attempt)
        self.assertFalse((self.data / "settings.conf.new").exists())

    def test_menu_opens_without_arguments(self):
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        launch = next(call for call in calls if "--logfile" in call)
        self.assertNotIn("--world", launch)
        self.assertNotIn("--go", launch)

    def test_check_is_read_only_with_missing_defaults(self):
        self.defaults.unlink()
        result = self.launch("--check")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.data.exists())
        self.assertFalse(self.dialogs.exists())
        self.no_engine_launch()

    def test_success_and_argument_forwarding_native(self):
        self.check_success()

    def test_success_and_argument_forwarding_flatpak(self):
        self.flatpak()
        self.check_success()

    def check_stdin(self):
        self.env["GE_TEST_MODE"] = "stdin"
        result = self.launch("--server", "--terminal", input="local console input\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.work / "stdin.txt").read_text(), "local console input\n")
        self.assertFalse(self.dialogs.exists())

    def test_native_child_keeps_launcher_stdin(self):
        self.check_stdin()

    def test_flatpak_child_keeps_launcher_stdin(self):
        self.flatpak()
        self.check_stdin()

    def check_success(self):
        result = self.launch("--server", "--quiet")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.dialogs.exists())
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        launch = next(call for call in calls if "--logfile" in call)
        self.assertEqual(launch[-2:], ["--server", "--quiet"])
        self.assertEqual(launch[launch.index("--world") + 1], str(self.data / "worlds/playtest"))
        self.assertEqual((self.data / "settings.conf").read_bytes(), self.defaults.read_bytes())
        self.assertIn("gameid = golden_era_playtest", (self.data / "worlds/playtest/world.mt").read_text())
        self.assertFalse(list((self.data / "logs").glob("flatpak-instance.*")))

    def check_engine_failure(self, backend, log):
        if backend == "flatpak":
            self.flatpak()
        client_log = self.data / "logs/client.log"
        if log == "stale":
            client_log.parent.mkdir(parents=True)
            client_log.write_bytes(b"Previous session log\n")
        self.env["GE_TEST_MODE"] = "log" if log == "current" else "fail"
        result = self.launch()
        self.dialog(result, "The game exited with status 42")
        self.assertIn("run sh ./start.sh", result.stderr.lower())
        if log == "absent":
            self.assertIn("before a client log was available", result.stderr)
            self.assertFalse(client_log.exists())
        else:
            self.assertIn(str(client_log), result.stderr)
            self.assertIn("may be from an earlier session", result.stderr)
            self.assertEqual(client_log.read_bytes(), b"Current test client log\n" if log == "current" else b"Previous session log\n")

    def test_native_failure_without_log(self):
        self.check_engine_failure("native", "absent")

    def test_native_failure_current_log(self):
        self.check_engine_failure("native", "current")

    def test_native_failure_stale_log(self):
        self.check_engine_failure("native", "stale")

    def test_flatpak_failure_without_log(self):
        self.check_engine_failure("flatpak", "absent")

    def test_flatpak_failure_current_log(self):
        self.check_engine_failure("flatpak", "current")

    def test_flatpak_failure_stale_log(self):
        self.check_engine_failure("flatpak", "stale")

    def test_xmessage_fallback(self):
        (self.bin / "zenity").unlink()
        self.executable(self.bin / "xmessage", self.dialog_stub)
        self.env["GE_TEST_MODE"] = "fail"
        self.dialog(self.launch(), "The game exited with status 42")

    def test_headless_failure_uses_stderr_without_a_dialog(self):
        self.env.update(DISPLAY="", WAYLAND_DISPLAY="", GE_TEST_MODE="fail")
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("The game exited with status 42", result.stderr)
        self.assertFalse(self.dialogs.exists())

    def check_interruption(self, backend, sig):
        if backend == "flatpak":
            self.flatpak()
        self.env["GE_TEST_MODE"] = "wait"
        process = subprocess.Popen([str(self.launcher)], env=self.env, text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        child = None
        try:
            deadline = time.monotonic() + 5
            while not self.ready.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(self.ready.exists(), "Engine stub did not become ready")
            child = int(self.ready.read_text())
            os.kill(process.pid, sig)
            stdout, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 128 + sig, stdout + stderr)
            self.assertEqual(self.stopped.read_text(), str(signal.SIGTERM))
            with self.assertRaises(ProcessLookupError):
                os.kill(child, 0)
            self.assertFalse(self.dialogs.exists())
            self.assertNotIn("The game exited", stderr)
            self.assertFalse(list((self.data / "logs").glob("flatpak-instance.*")))
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate(timeout=5)
            if child:
                try:
                    os.kill(child, signal.SIGKILL)
                except ProcessLookupError:
                    pass

    def test_native_interrupt_reaps_engine_without_crash_dialog(self):
        self.check_interruption("native", signal.SIGINT)

    def test_native_terminate_reaps_engine_without_crash_dialog(self):
        self.check_interruption("native", signal.SIGTERM)

    def test_flatpak_hangup_reaps_engine_without_crash_dialog(self):
        self.check_interruption("flatpak", signal.SIGHUP)

    def test_flatpak_terminate_reaps_engine_without_crash_dialog(self):
        self.check_interruption("flatpak", signal.SIGTERM)

    def test_flatpak_interrupt_reaps_monitor_and_engine(self):
        self.check_interruption("flatpak", signal.SIGINT)

    def test_flatpak_delayed_instance_id_still_requests_normal_shutdown(self):
        self.flatpak()
        self.env.update(GE_TEST_MODE="wait", GE_TEST_ID_DELAY="0.3")
        process = subprocess.Popen([str(self.launcher)], env=self.env, text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        try:
            deadline = time.monotonic() + 5
            monitor = self.work / "monitor.pid"
            while not monitor.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(monitor.exists())
            self.assertFalse(self.ready.exists(), "Interrupt before sandbox readiness")
            os.kill(process.pid, signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=8)
            self.assertEqual(process.returncode, 143, stdout + stderr)
            self.assertEqual(self.stopped.read_text(), str(signal.SIGTERM))
            self.assertNotIn("left running", stderr)
            self.assertFalse(list((self.data / "logs").glob("flatpak-instance.*")))
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate(timeout=5)

    def test_flatpak_unavailable_enter_leaves_game_running_with_explicit_message(self):
        self.flatpak()
        self.env.update(GE_TEST_MODE="wait", GE_TEST_ENTER_FAIL="1")
        process = subprocess.Popen([str(self.launcher)], env=self.env, text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        child = monitor = None
        try:
            deadline = time.monotonic() + 5
            while not self.ready.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(self.ready.exists())
            child = int(self.ready.read_text())
            monitor = int((self.work / "monitor.pid").read_text())
            os.kill(process.pid, signal.SIGTERM)
            process.wait(timeout=8)
            self.assertEqual(process.returncode, 143)
            self.assertFalse(self.stopped.exists())
            os.kill(child, 0)
            os.kill(monitor, 0)
            self.assertFalse(self.dialogs.exists())
            self.assertFalse(list((self.data / "logs").glob("flatpak-instance.*")))
            # The intentionally running child still owns stdout/stderr. Close
            # this harmless fixture normally before collecting those streams.
            os.kill(child, signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=5)
            self.assertIn("The game was left running", stderr)
            self.assertIn("No forced shutdown was sent", stderr)
        finally:
            if child:
                try:
                    os.kill(child, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate(timeout=5)


if __name__ == "__main__":
    stream = io.StringIO()
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(LaunchErrors))
    report = ("Current Linux launcher startup diagnostics\n"
              "Copied source template; harmless native/Flatpak/dialog stubs only; no engine, ports or profile writes.\n"
              "Source SHA256: " + hashlib.sha256(SOURCE.read_bytes()).hexdigest() + "\n\n" + stream.getvalue())
    BASE.mkdir(parents=True, exist_ok=True)
    evidence = BASE / "linux-launch-errors.txt"
    evidence.write_text(report)
    print(report)
    print("Evidence: " + str(evidence))
    sys.exit(not result.wasSuccessful())
