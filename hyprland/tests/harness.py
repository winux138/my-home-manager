"""Harness utilities for disposable nested Hyprland tests."""

from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import select
import shutil
import signal
import subprocess
import tempfile
import time

HYPRLAND_SOURCE = Path(__file__).resolve().parents[1]


@contextmanager
def session(with_observer=False, outputs_only=False):
    parent_runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    display = Path(os.environ["WAYLAND_DISPLAY"])
    if not display.is_absolute():
        display = parent_runtime / display
    assert display.is_socket(), "Run from an existing Wayland session"
    hyprctl = shutil.which("hyprctl")
    hyprland = shutil.which("Hyprland")
    sync = shutil.which("hypr-sync-outputs")
    xwayland = shutil.which("Xwayland")
    assert xwayland and xwayland.startswith("/nix/store/"), "Enter nix develop .#hyprland-test for Nix Xwayland"

    processes = []
    logs = []
    children = {}
    child_exits = select.poll()

    def track_children(pid):
        try:
            pids = [int(value) for value in Path(f"/proc/{pid}/task/{pid}/children").read_text().split()]
        except (FileNotFoundError, ProcessLookupError):
            return []
        for child in pids:
            if child not in children:
                try:
                    children[child] = os.pidfd_open(child)
                except ProcessLookupError:
                    continue
                child_exits.register(children[child], select.POLLIN)
        return pids

    with tempfile.TemporaryDirectory(prefix="hs.", dir="/tmp") as directory:
        runtime = Path(directory)
        state = runtime / "hypr-session"
        config_home = runtime / "config"
        state.mkdir()
        config_home.mkdir()
        env = dict(
            os.environ,
            XDG_RUNTIME_DIR=directory,
            XDG_CONFIG_HOME=str(config_home),
            WAYLAND_DISPLAY=str(display),
            HYPRLAND_INSTANCE_SIGNATURE="",
            HYPR_AUTOSTART="0",
            HYPRLAND_NO_SD_VARS="1",
            HYPRLAND_NO_SD_TARGET="1",
            MONIQUE_MONITORS_LUA="",
            LIBSEAT_BACKEND="seatd",
            SEATD_SOCK=str(runtime / "no-seatd.sock"),
        )
        env.pop("DISPLAY", None)

        def start(arguments, environment=env):
            log = (runtime / f"process-{len(processes)}.log").open("w+")
            logs.append(log)
            process = subprocess.Popen(arguments, env=environment, stdout=log, stderr=log)
            processes.append(process)
            return process

        def query(instance, *arguments):
            return json.loads(subprocess.check_output(
                [hyprctl, "-i", instance, "-j", *arguments], env=env, text=True, timeout=5))

        def command(instance, *arguments):
            result = subprocess.check_output(
                [hyprctl, "-i", instance, *arguments], env=env, text=True, timeout=10)
            assert result.strip() == "ok", result

        def until(predicate, message="Hotplug did not converge"):
            deadline = time.monotonic() + 40
            while time.monotonic() < deadline:
                value = predicate()
                if value:
                    return value
                time.sleep(0.1)
            raise AssertionError(message)

        def compositor(config, environment):
            if outputs_only:
                original = Path(config)
                wrapper = runtime / original.name
                wrapper.write_text(
                    'package.path = %s .. package.path\ndofile(%s)\n'
                    'hl.config({debug={vfr=false,damage_tracking=0}})\n'
                    'hl.monitor({output="WAYLAND-1",position="0x0",scale=1})\n'
                    % (json.dumps(str(original.parent / "?.lua") + ";"), json.dumps(config))
                )
                config = str(wrapper)
            process = start([hyprland, "--config", config], environment)

            def instance():
                track_children(process.pid)
                assert process.poll() is None, "Test compositor exited"
                if not any(path.is_socket() for path in (runtime / "hypr").glob("*/.socket.sock")):
                    return None
                raw = subprocess.check_output(
                    [hyprctl, "-j", "instances"], env=env, text=True, timeout=5)
                entries = json.loads(raw)
                return next((item for item in entries if item["pid"] == process.pid), None)

            return until(instance)

        watcher = None
        try:
            observer = None
            outer_env = env
            if with_observer:
                observer = compositor(os.environ["OUTER_HYPRLAND_CONFIG"], env)
                command(observer["instance"], "eval", 'hl.config({decoration={screen_shader=""}})')
                outer_env = dict(env, WAYLAND_DISPLAY=observer["wl_socket"])
            outer = compositor(os.environ["OUTER_HYPRLAND_CONFIG"], outer_env)
            inner_env = dict(env, WAYLAND_DISPLAY=outer["wl_socket"],
                             OUTER_HYPRLAND_INSTANCE=outer["instance"])
            inner = compositor(os.environ["INNER_HYPRLAND_CONFIG"], inner_env)
            for role, info in (("outer", outer), ("inner", inner)):
                for field, key in (("pid", "pid"), ("instance", "instance"), ("socket", "wl_socket")):
                    (state / f"{role}.{field}").write_text(str(info[key]) + "\n")
            host, guest = outer["instance"], inner["instance"]
            until(lambda: any(plugin["name"] == "hyprfocus" for plugin in query(guest, "plugin", "list")),
                  "Hyprfocus did not load against the selected Hyprland build")
            xdisplay = subprocess.check_output(
                [hyprctl, "-i", guest, "repl", 'os.getenv("DISPLAY")'],
                env=env, text=True, timeout=5).strip()
            assert re.fullmatch(r":[0-9]+", xdisplay), xdisplay
            inner_env["DISPLAY"] = xdisplay

            def xserver():
                for pid in track_children(inner["pid"]):
                    try:
                        executable = Path(f"/proc/{pid}/exe").resolve()
                        if str(executable).startswith("/nix/store/") and executable.name == "Xwayland":
                            return pid
                    except OSError:
                        pass
                return None

            server = until(xserver, "The inner compositor did not start the Nix Xwayland executable")
            assert query(host, "getoption", "xwayland:enabled")["bool"] is False

            watcher_env = dict(env)
            watcher_env["BASH_FUNC_hyprctl%%"] = '''() {
                if [[ -n "${HOST_RPC_TRACE-}" ]]; then
                    printf '%%s\\n' "$*" >>"$HOST_RPC_TRACE"
                fi
                if [[ "${2-}" == "%s" && "${3-}" == -j && "${4-}" == monitors ]]; then
                    "%s" "$@" | "%s" 'map(if (.name | startswith("TEST-BIG-")) then .description = "Hotplug fixture S430c serial-001" else . end)'
                else
                    "%s" "$@"
                fi
            }''' % (host, hyprctl, shutil.which("jq"), hyprctl)

            def start_watcher():
                nonlocal watcher
                watcher = start([sync, "--watch"], watcher_env)
                until(lambda: any(m["name"].startswith("split-") for m in query(guest, "monitors")))
                return watcher

            def connect(name, mode="3840x1200@60", position="640x0"):
                command(host, "eval", 'hl.monitor({output="%s",mode="%s",'
                        'position="%s",scale=1,transform=0})' % (name, mode, position))
                command(host, "output", "create", "headless", name)

            yield {
                "command": command,
                "config_home": config_home,
                "connect": connect,
                "env": env,
                "guest": guest,
                "host": host,
                "hyprctl": hyprctl,
                "inner": inner,
                "inner_env": inner_env,
                "observer": observer,
                "outer": outer,
                "query": query,
                "runtime": runtime,
                "server": server,
                "start": start,
                "start_watcher": start_watcher,
                "state": state,
                "sync": sync,
                "until": until,
                "watcher_env": watcher_env,
                "xserver": xserver,
            }
        except BaseException:
            if watcher is not None:
                print("Watcher status:", watcher.poll())
            if "guest" in locals():
                for instance in (host, guest):
                    try:
                        print(instance, [{k: m[k] for k in ("id", "name", "width", "height", "x", "y", "scale", "transform", "disabled", "focused")}
                                         for m in query(instance, "monitors", "all")])
                        print([{k: c[k] for k in ("address", "pid", "monitor", "at", "size", "workspace")} for c in query(instance, "clients")])
                        print("Cursor:", query(instance, "cursorpos"), "Active window:", query(instance, "activewindow").get("address"))
                        print("Config errors:", subprocess.check_output([hyprctl, "-i", instance, "configerrors"], env=env, text=True, timeout=5))
                    except Exception as error:
                        print("State unavailable:", error)
            for log in logs:
                log.seek(0)
                print("".join(log.readlines()[-12:]))
            raise
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    if process.args and process.args[0] == hyprland:
                        track_children(process.pid)
                    process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            for log in logs:
                log.close()
            pending = set(children.values())
            deadline = time.monotonic() + 5
            while pending and time.monotonic() < deadline:
                for descriptor, _ in child_exits.poll(50):
                    pending.discard(descriptor)
                    child_exits.unregister(descriptor)
            for descriptor in pending:
                try:
                    signal.pidfd_send_signal(descriptor, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            for descriptor in children.values():
                os.close(descriptor)
            assert not pending, "Compositor children survived shutdown: %s" % [pid for pid, fd in children.items() if fd in pending]
