"""Run inside nix develop .#hyprland-test from a Wayland session; uses disposable compositors."""

import argparse
import json
import subprocess

from checks_outputs import check_gestures, check_outputs, check_xwayland
from harness import session


def check_split_and_recovery(recovery_only=False):
    with session(with_observer=not recovery_only) as ctx:
        command, connect, env = ctx["command"], ctx["connect"], ctx["env"]
        guest, host, hyprctl = ctx["guest"], ctx["host"], ctx["hyprctl"]
        inner, inner_env, observer = ctx["inner"], ctx["inner_env"], ctx["observer"]
        outer, query, start = ctx["outer"], ctx["query"], ctx["start"]
        state, sync, until = ctx["state"], ctx["sync"], ctx["until"]
        watcher_env = ctx["watcher_env"]
        watcher = ctx["start_watcher"]()

        connect("TEST-BIG-1", "2560x1200@60")
        identity = "Hotplug fixture S430c serial-001"
        base = until(lambda: json.loads((state / "output-map.json").read_text()).get(identity))
        until(lambda: any(m["name"] == base and m["width"] == 2560 for m in query(guest, "monitors")))
        command(host, "eval", 'hl.monitor({output="TEST-BIG-1",mode="3840x1200@60",'
                'position="640x0",scale=1,transform=0})')
        expected = {base + "-left": (640, 1120), base: (1760, 1600), base + "-right": (3360, 1120)}

        def split_ready():
            actual = {m["name"]: (m["x"], m["width"]) for m in query(guest, "monitors")
                      if m["height"] == 1200 and m["transform"] == 0}
            return all(actual.get(name) == shape for name, shape in expected.items())

        until(split_ready)
        until(lambda: all(m["name"] != "WAYLAND-1" for m in query(guest, "monitors")))
        command(guest, "eval", 'hl.device({name="hl-virtual-keyboard-wtype",resolve_binds_by_sym=true})')
        client_env = dict(inner_env, WAYLAND_DISPLAY=inner["wl_socket"], HYPRLAND_INSTANCE_SIGNATURE=guest)
        command(guest, "dispatch", 'hl.dsp.focus({monitor="%s"})' % (base + "-right"))
        for key, target in (("comma", base), ("comma", base + "-left"),
                            ("period", base), ("period", base + "-right")):
            subprocess.run(["wtype", "-s", "100", "-M", "logo", "-P", key, "-p", key, "-m", "logo"],
                           env=client_env, check=True, timeout=5)
            until(lambda: any(m["name"] == target and m["focused"] for m in query(guest, "monitors")))
        print("PASS: actual comma/period shortcuts follow left-middle-right spatial order")

        terminal = start(["foot", "--app-id=hotplug-sentinel",
                          "--override=colors-dark.background=ffffff",
                          "--override=colors-light.background=ffffff",
                          "--override=colors-dark.alpha=1",
                          "--override=colors-light.alpha=1", "sleep", "600"], client_env)
        window = until(lambda: next((c for c in query(guest, "clients") if c["pid"] == terminal.pid), None))
        workspace = next(m["activeWorkspace"]["id"] for m in query(guest, "monitors") if m["name"] == base)
        command(guest, "dispatch", 'hl.dsp.window.move({workspace=%d,window="address:%s",follow=false})'
                % (workspace, window["address"]))
        before = {m["name"]: m["id"] for m in query(guest, "monitors", "all")}
        for key, target in (("comma", base + "-left"), ("period", base)):
            command(guest, "dispatch", 'hl.dsp.focus({window="address:%s"})' % window["address"])
            subprocess.run(["wtype", "-s", "100", "-M", "logo", "-M", "shift", "-P", key, "-p", key,
                            "-m", "shift", "-m", "logo"], env=client_env, check=True, timeout=5)
            until(lambda: any(c["address"] == window["address"] and c["monitor"] == before[target]
                              for c in query(guest, "clients")))
        print("PASS: shifted shortcuts move the window left and back to the middle")

        if not recovery_only:
            assert observer is not None
            primary = next(m for m in query(host, "monitors") if m["name"] == "WAYLAND-1")
            assert primary["scale"] == 1 and primary["transform"] == 0
            presented_output = json.loads((state / "output-map.json").read_text())[primary["description"] or "port:" + primary["name"]]
            presented_monitor = next(m for m in query(guest, "monitors") if m["name"] == presented_output)
            command(guest, "dispatch", 'hl.dsp.window.move({workspace=%d,window="address:%s",follow=false})'
                    % (presented_monitor["activeWorkspace"]["id"], window["address"]))
            host_capture_env = dict(client_env, WAYLAND_DISPLAY=outer["wl_socket"])
            observer_env = dict(env, WAYLAND_DISPLAY=observer["wl_socket"])

            def pixel(environment, geometry):
                ppm = subprocess.check_output(["grim", "-g", geometry, "-t", "ppm", "-"], env=environment, timeout=5)
                rgb = tuple(ppm.split(b"\n", 3)[3])
                assert len(rgb) == 3, rgb
                return rgb

            def pixels():
                client = next(c for c in query(guest, "clients") if c["pid"] == terminal.pid)
                primary = next(m for m in query(host, "monitors") if m["name"] == "WAYLAND-1")
                shown = next(c for c in query(observer["instance"], "clients")
                             if c["pid"] == outer["pid"] and c["title"] == "aquamarine - WAYLAND-1")
                x, y = client["at"][0] + client["size"][0] // 2, client["at"][1] + client["size"][1] // 2
                geometry = "%d,%d 1x1" % (x, y)
                shown_x = shown["at"][0] + round((x - primary["x"]) * shown["size"][0] / primary["width"])
                shown_y = shown["at"][1] + round((y - primary["y"]) * shown["size"][1] / primary["height"])
                return (pixel(client_env, geometry), pixel(host_capture_env, geometry),
                        pixel(observer_env, "%d,%d 1x1" % (shown_x, shown_y)))

            for temperature, matches in (
                ("off", lambda rgb: rgb == (255, 255, 255)),
                ("2500", lambda rgb: rgb[0] > rgb[1] > rgb[2]),
                ("10000", lambda rgb: rgb[0] < rgb[1] < rgb[2]),
                ("off", lambda rgb: rgb == (255, 255, 255)),
            ):
                subprocess.run(["blue-light", temperature], env=client_env, check=True, timeout=10)
                until(lambda: (lambda p: p[0] == p[1] == (255, 255, 255) and matches(p[2]))(pixels()),
                      "Filter %s: displayed colors or unfiltered captures are incorrect" % temperature)
            command(guest, "dispatch", 'hl.dsp.window.move({workspace=%d,window="address:%s",follow=false})'
                    % (workspace, window["address"]))
            print("PASS: displayed warm/cool/off colors and unfiltered inner/outer screenshots")

        def split_hosts():
            return [c for c in query(host, "clients") if c["pid"] == inner["pid"]
                    and c["title"].removeprefix("aquamarine - ") in expected]

        command(host, "output", "remove", "TEST-BIG-1")
        until(lambda: len(split_hosts()) == 3 and all(
            c["workspace"]["name"] == "special:hypr-disconnected" for c in split_hosts()))
        assert {m["name"]: m["id"] for m in query(guest, "monitors", "all")} == before
        connect("TEST-BIG-91")
        until(split_ready)
        monitor_id = next(m["id"] for m in query(host, "monitors") if m["name"] == "TEST-BIG-91")
        until(lambda: len(split_hosts()) == 3 and all(
            c["monitor"] == monitor_id and c["floating"] and
            c["workspace"]["name"] != "special:hypr-disconnected" for c in split_hosts()))
        profile = ctx["config_home"] / "monique/outputs/monitors.lua"
        profile.parent.mkdir(parents=True)
        profile.write_text('hl.monitor({output="TEST-BIG-91",mode="3840x1200@60",position="740x0",scale=1,transform=0})\n')
        expected = {name: (x + 100, width) for name, (x, width) in expected.items()}
        command(host, "reload")
        until(split_ready)
        for _ in range(2):
            subprocess.run([sync], env=watcher_env, check=True, timeout=30)
        assert {m["name"]: m["id"] for m in query(guest, "monitors", "all")} == before
        survivor = next(c for c in query(guest, "clients") if c["address"] == window["address"])
        assert (survivor["pid"], survivor["workspace"]["id"]) == (terminal.pid, workspace)
        assert watcher.poll() is None
        print("PASS: late split, EDID port change, parked hosts, reload, stable output IDs, window/workspace survival, idempotence")

        monitors = {m["name"]: m for m in query(guest, "monitors")}
        destination = monitors[base + "-left"]["activeWorkspace"]["id"]
        destination_monitor = monitors[base + "-left"]["id"]
        parked_workspace = monitors[base + "-right"]["activeWorkspace"]["id"]
        connect("TEST-DISABLED", "640x480@60", "9000x0")
        disabled_output = until(lambda: json.loads((state / "output-map.json").read_text()).get("port:TEST-DISABLED"))
        until(lambda: any(m["name"] == disabled_output for m in query(guest, "monitors")))
        command(host, "eval", 'hl.monitor({output="TEST-DISABLED",disabled=true})')
        until(lambda: any(m["name"] == "TEST-DISABLED" and m["disabled"] for m in query(host, "monitors", "all")))

        def recovery_window(app_id, target):
            command(guest, "dispatch", 'hl.dsp.focus({workspace=%d})' % destination)
            process = start(["foot", "--app-id=" + app_id, "sleep", "600"], client_env)
            client = until(lambda: next((c for c in query(guest, "clients") if c["pid"] == process.pid), None))
            command(guest, "dispatch", 'hl.dsp.window.move({workspace=%s,window="address:%s",follow=false})'
                    % (json.dumps(target), client["address"]))
            return client["address"]

        inactive = recovery_window("gather-inactive", destination + 1)
        parked = recovery_window("gather-parked", parked_workspace)
        scratch = recovery_window("gather-scratch", "special:gather-smoke")
        named = recovery_window("gather-named", "name:gather-named")
        keeper = recovery_window("gather-destination", destination)
        gather_env = dict(client_env, **{"BASH_FUNC_hyprctl%%": watcher_env["BASH_FUNC_hyprctl%%"]})
        for target in (destination, destination + 2):
            recovery_window("gather-connected-unreachable-%d" % target, 9001)
            command(guest, "dispatch", 'hl.dsp.focus({workspace=%d})' % target)
            focused = query(guest, "activewindow").get("address")
            cursor, outer_cursor = query(guest, "cursorpos"), query(host, "cursorpos")
            before_gather = {c["address"]: (c["pid"], c["workspace"]["address"], c["monitor"], c["pinned"])
                             for c in query(guest, "clients")}
            connected_outputs = {m["name"]: m["id"] for m in query(guest, "monitors", "all")}
            subprocess.run(["hypr-gather-windows"], env=gather_env, check=True, timeout=30)
            unchanged = {c["address"]: (c["pid"], c["workspace"]["address"], c["monitor"], c["pinned"])
                         for c in query(guest, "clients")}
            assert unchanged == before_gather, "Recovery changed windows on connected monitors"
            assert {m["name"]: m["id"] for m in query(guest, "monitors", "all")} == connected_outputs
            assert query(guest, "activeworkspace")["address"] == str(target)
            if focused:
                assert query(guest, "activewindow")["address"] == focused
            assert query(guest, "cursorpos") == cursor and query(host, "cursorpos") == outer_cursor
        print("PASS: no disconnected outputs means no changes, including unreachable connected workspace numbers and empty destinations")

        connect("TEST-DISCONNECTED", position="5000x0")
        disconnected_output = until(lambda: json.loads((state / "output-map.json").read_text()).get("port:TEST-DISCONNECTED"))
        disconnected_outputs = {disconnected_output, disconnected_output + "-left", disconnected_output + "-right"}
        until(lambda: disconnected_outputs <= {m["name"] for m in query(guest, "monitors")})
        disconnected_workspace = next(m["activeWorkspace"]["id"] for m in query(guest, "monitors") if m["name"] == disconnected_output)
        lost_active = recovery_window("gather-disconnected-active", disconnected_workspace)
        lost_inactive = recovery_window("gather-disconnected-inactive", 9002)
        lost_named = recovery_window("gather-disconnected-named", "name:recover-named")
        lost_special = recovery_window("gather-disconnected-special", "special:recover-lost")
        for selector in (9002, "name:recover-named", "special:recover-lost"):
            command(guest, "dispatch", 'hl.dsp.workspace.move({workspace=%s,monitor="%s"})'
                    % (json.dumps(selector), disconnected_output))
        pinned_workspace = next(m["activeWorkspace"]["id"] for m in query(guest, "monitors")
                                if m["name"] == disconnected_output + "-left")
        pinned = recovery_window("gather-disconnected-pinned", pinned_workspace)
        for action in ("float", "pin"):
            command(guest, "dispatch", 'hl.dsp.window.%s({window="address:%s",action="on"})' % (action, pinned))
        command(host, "output", "remove", "TEST-DISCONNECTED")
        until(lambda: any(c["title"] == "aquamarine - " + disconnected_output and
                          c["workspace"]["name"] == "special:hypr-disconnected"
                          for c in query(host, "clients") if c["pid"] == inner["pid"]))
        parked_host = next(c for c in split_hosts() if c["title"] == "aquamarine - " + base + "-right")
        command(host, "dispatch", 'hl.dsp.window.move({workspace="special:gather-hidden",window="address:%s",follow=false})'
                % parked_host["address"])
        command(guest, "dispatch", 'hl.dsp.focus({window="address:%s"})' % keeper)
        original_clients = {c["address"]: c for c in query(guest, "clients")}
        identities = {address: (c["pid"], c["workspace"]["address"]) for address, c in original_clients.items()}
        original_outputs = {m["name"]: m["id"] for m in query(guest, "monitors", "all")}
        identity_map = (state / "output-map.json").read_text()
        for reply, status in (("false", 0), ("0 none", 17)):
            error_env = dict(gather_env)
            error_env["BASH_FUNC_hyprctl%%"] = '''() {
                if [[ "${3-}" == repl ]]; then printf '%%s\\n' '%s'; return %d; fi
                "%s" "$@"
            }''' % (reply, status, hyprctl)
            failed = subprocess.run(["hypr-gather-windows"], env=error_env, capture_output=True, text=True, timeout=30)
            assert failed.returncode != 0, "Failed transfer allowed output removal"
            assert {m["name"]: m["id"] for m in query(guest, "monitors", "all")} == original_outputs
        subprocess.run(["hypr-gather-windows"], env=gather_env, check=True, timeout=30)
        recovered = {c["address"]: c for c in query(guest, "clients")}
        gathered = {lost_active, lost_inactive, lost_named, lost_special, pinned}
        assert {address: c["pid"] for address, c in recovered.items()} == {address: value[0] for address, value in identities.items()}
        assert all(c["workspace"]["address"] == (str(destination) if address in gathered else identities[address][1])
                   for address, c in recovered.items())
        assert all(recovered[address]["monitor"] == destination_monitor for address in gathered | {keeper})
        assert recovered[pinned]["pinned"]
        assert all(recovered[address]["monitor"] == original_clients[address]["monitor"]
                   for address in (inactive, parked, scratch, named, window["address"]))
        remaining = {name: ident for name, ident in original_outputs.items() if name not in disconnected_outputs}
        until(lambda: {m["name"]: m["id"] for m in query(guest, "monitors", "all")} == remaining)
        until(lambda: not any(c["title"].removeprefix("aquamarine - ") in disconnected_outputs
                              for c in query(host, "clients") if c["pid"] == inner["pid"]))
        until(lambda: not {identities[address][1] for address in gathered}
              & {w["address"] for w in query(guest, "workspaces")}, "Empty disconnected workspaces did not disappear")
        assert (state / "output-map.json").read_text() == identity_map
        assert query(guest, "activewindow")["address"] == keeper
        until(lambda: query(host, "cursorpos") == query(guest, "cursorpos"))
        assignments = {address: (c["workspace"]["address"], c["monitor"]) for address, c in recovered.items()}
        subprocess.run(["hypr-gather-windows"], env=gather_env, check=True, timeout=30)
        subprocess.run([sync], env=watcher_env, check=True, timeout=30)
        assert {c["address"]: (c["workspace"]["address"], c["monitor"]) for c in query(guest, "clients")} == assignments
        assert {m["name"]: m["id"] for m in query(guest, "monitors", "all")} == remaining
        assert query(guest, "activewindow")["address"] == keeper
        connect("TEST-DISCONNECTED", position="5000x0")
        until(lambda: disconnected_outputs <= {m["name"] for m in query(guest, "monitors")})
        assert {c["address"]: c["pid"] for c in query(guest, "clients")} == {address: value[0] for address, value in identities.items()}
        assert (state / "output-map.json").read_text() == identity_map
        print("PASS: disconnected-only gathering into one workspace, pinned/named/special windows, empty workspace/output cleanup, connected/disabled/hidden protection, failures, repetition, and reconnection")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--gestures", action="store_true", help="Run focused workspace gesture checks")
    group.add_argument("--outputs", action="store_true", help="Run focused output initialization and parking checks")
    group.add_argument("--recovery", action="store_true", help="Run workspace recovery without the output and screenshot checks")
    group.add_argument("--xwayland", action="store_true", help="Run X11 startup, display routing, and shutdown checks")
    args = parser.parse_args()
    if args.xwayland or not (args.gestures or args.outputs or args.recovery):
        check_xwayland()
    if not (args.gestures or args.recovery or args.xwayland):
        check_outputs()
    if args.gestures:
        check_gestures()
    elif not (args.outputs or args.xwayland):
        check_split_and_recovery(recovery_only=args.recovery)
