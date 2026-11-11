"""Focused XWayland, gesture, and output/parking checks."""

import json
from pathlib import Path
import shutil
import subprocess
import time

from harness import HYPRLAND_SOURCE, session


def check_xwayland():
    with session() as ctx:
        guest, inner, inner_env = ctx["guest"], ctx["inner"], ctx["inner_env"]
        query, start, until = ctx["query"], ctx["start"], ctx["until"]
        xmessage = shutil.which("xmessage")
        assert xmessage and xmessage.startswith("/nix/store/"), "xmessage must come from nix develop .#hyprland-test"
        client_env = dict(inner_env, WAYLAND_DISPLAY=inner["wl_socket"], HYPRLAND_INSTANCE_SIGNATURE=guest)
        client = start([xmessage, "-title", "split-x11-smoke", "Nested XWayland smoke test"], client_env)
        until(lambda: any(c["xwayland"] and c["title"] == "split-x11-smoke" for c in query(guest, "clients")),
              "The X11 client did not map in the inner compositor")
        assert ctx["xserver"]() == ctx["server"], "The ready X server is not the Nix Xwayland process"
        assert b"-ac" not in Path(f"/proc/{ctx['server']}/cmdline").read_bytes().split(b"\0"), "X11 access control was disabled"
        native = start(["foot", "--app-id=native-wayland-control", "sleep", "600"], client_env)
        until(lambda: any(c["pid"] == native.pid and not c["xwayland"] for c in query(guest, "clients")),
              "Native Wayland did not work alongside XWayland")
        ctx["command"](guest, "dispatch", "hl.dsp.exit()")
        client.wait(timeout=5)
        native.wait(timeout=5)
        print("PASS: Nix Xwayland, inner DISPLAY handoff, X11/Wayland coexistence, and client shutdown")


def check_gestures():
    with session() as ctx:
        command, guest, host = ctx["command"], ctx["guest"], ctx["host"]
        inner, inner_env, query = ctx["inner"], ctx["inner_env"], ctx["query"]
        start, until = ctx["start"], ctx["until"]
        ctx["start_watcher"]()
        until(lambda: all(m["name"].startswith("split-") for m in query(guest, "monitors")))
        target = next(m for m in query(guest, "monitors") if m["focused"])
        first = target["activeWorkspace"]["id"]
        client_env = dict(inner_env, WAYLAND_DISPLAY=inner["wl_socket"], HYPRLAND_INSTANCE_SIGNATURE=guest)
        for workspace in (first, first + 1, first + 2):
            command(guest, "dispatch", 'hl.dsp.focus({workspace=%d})' % workspace)
            terminal = start(["foot", "--app-id=gesture-sentinel", "sleep", "600"], client_env)
            until(lambda: any(c["pid"] == terminal.pid for c in query(guest, "clients")))

        command(host, "eval", 'hl.monitor({output="GESTURE-OTHER",mode="640x480@60",position="10000x0",scale=1})')
        command(host, "output", "create", "headless", "GESTURE-OTHER")
        other = until(lambda: next((m for m in query(guest, "monitors") if m["name"] != target["name"]), None))
        other_workspace = other["activeWorkspace"]["id"]
        inner_runtime = json.dumps(str(HYPRLAND_SOURCE / "inner-runtime.lua"))
        command(guest, "eval", 'dofile(%s).sync_after(hl.dsp.focus({workspace=%d}))()' % (inner_runtime, first))
        until(lambda: query(host, "cursorpos") == query(guest, "cursorpos"))
        command(host, "eval", '_gesture_test=dofile(%s).workspace_swipe(%s,150)'
                % (json.dumps(str(HYPRLAND_SOURCE / "outer-runtime.lua")), inner_runtime))
        workspace_ids = {w["id"] for w in query(guest, "workspaces")}

        def active_workspace():
            return query(guest, "activeworkspace")["id"]

        current = first
        for deltas, cancelled, expected_workspace in (
            ([-149], False, first),
            ([-200], True, first),
            ([-75, -75], False, first + 1),
            ([150], False, first),
            ([150], False, first + 2),
            ([-1000, -1000], False, first),
        ):
            calls = ["_gesture_test.start({})"]
            calls.extend("_gesture_test.update({delta={x=%d,y=0}})" % delta for delta in deltas)
            calls.append("_gesture_test.finish({cancelled=%s})" % str(cancelled).lower())
            command(host, "eval", ";".join(calls))
            if expected_workspace == current:
                time.sleep(0.5)
            else:
                until(lambda: active_workspace() == expected_workspace)
            assert active_workspace() == expected_workspace, (deltas, cancelled, query(guest, "activeworkspace"))
            until(lambda: query(host, "cursorpos") == query(guest, "cursorpos"))
            assert next(m for m in query(guest, "monitors") if m["name"] == other["name"])["activeWorkspace"]["id"] == other_workspace
            current = expected_workspace
        command(host, "eval", "_gesture_test.finish({cancelled=false})")
        time.sleep(0.5)
        assert active_workspace() == current, "Repeated finish committed a second step"
        assert {w["id"] for w in query(guest, "workspaces")} == workspace_ids
        print("PASS: gesture threshold, cancellation, one-step commit, direction, wraparound, monitor locality, and cursor sync")


def check_outputs():
    with session(outputs_only=True) as ctx:
        command, connect, env = ctx["command"], ctx["connect"], ctx["env"]
        guest, host, hyprctl = ctx["guest"], ctx["host"], ctx["hyprctl"]
        inner, inner_env, outer = ctx["inner"], ctx["inner_env"], ctx["outer"]
        query, runtime, start = ctx["query"], ctx["runtime"], ctx["start"]
        sync, until, watcher_env = ctx["sync"], ctx["until"], ctx["watcher_env"]
        watcher = ctx["start_watcher"]()

        output = "split-" + subprocess.check_output(
            ["hypr-output-id", "Hotplug fixture S430c serial-001"], env=env, text=True).strip()
        command(guest, "eval", 'hl.monitor({output="%s",disabled=true,position="10000x0",scale=1})' % output)
        command(guest, "output", "create", "wayland", output)
        stuck = until(lambda: next((m for m in query(guest, "monitors", "all") if m["name"] == output), None))
        assert stuck["disabled"], stuck
        assert not any(c["title"] == "aquamarine - " + output for c in query(host, "clients"))
        connect("TEST-BIG-BOOTSTRAP", "3440x1440@60", "10000x0")
        recovered = until(lambda: next((m for m in query(guest, "monitors")
                                       if m["name"] == output and (m["x"], m["width"], m["height"]) == (10000, 3440, 1440)), None),
                          "Existing hostless output did not recover")
        assert recovered["id"] == stuck["id"], "Bootstrap recreated the output"
        until(lambda: any(c["title"] == "aquamarine - " + output and c["at"] == [10000, 0]
                          and c["size"] == [3440, 1440] for c in query(host, "clients")))
        print("PASS: existing hostless output recovers without recreation")

        outer_runtime = json.dumps(str(HYPRLAND_SOURCE / "outer-runtime.lua"))
        before_hosts = {c["address"]: (c["at"], c["size"], c["workspace"], c["floating"]) for c in query(host, "clients")}
        command(host, "eval", 'local runtime=dofile(%s); '
                'assert(runtime.place_host("%s",0,1,nil)==false); '
                'assert(runtime.place_host("missing-output",%d,1,nil)==false)'
                % (outer_runtime, output, inner["pid"]))
        assert {c["address"]: (c["at"], c["size"], c["workspace"], c["floating"]) for c in query(host, "clients")} == before_hosts

        client_env = dict(inner_env, WAYLAND_DISPLAY=inner["wl_socket"], HYPRLAND_INSTANCE_SIGNATURE=guest)
        command(guest, "dispatch", 'hl.dsp.focus({monitor="%s"})' % output)
        terminal = start(["foot", "--app-id=parked-sentinel", "sleep", "600"], client_env)
        until(lambda: any(c["pid"] == terminal.pid for c in query(guest, "clients")))
        command(host, "output", "remove", "TEST-BIG-BOOTSTRAP")
        until(lambda: any(c["title"] == "aquamarine - " + output and
                          c["workspace"]["name"] == "special:hypr-disconnected" for c in query(host, "clients")))
        replacement = "split-" + subprocess.check_output(
            ["hypr-output-id", "port:TEST-REPLACEMENT"], env=env, text=True).strip()
        command(guest, "eval", 'hl.monitor({output="%s",disabled=true})' % replacement)
        connect("TEST-REPLACEMENT", "3440x1440@60", "10000x0")
        target = until(lambda: next((m for m in query(guest, "monitors")
                                     if m["name"] == replacement and m["width"] == 3440), None))
        visible = start(["foot", "--app-id=pointer-sentinel", "sleep", "600"], client_env)
        window = until(lambda: next((c for c in query(guest, "clients") if c["pid"] == visible.pid), None))
        command(guest, "dispatch", 'hl.dsp.window.move({window="address:%s",workspace=%d,follow=false})'
                % (window["address"], target["activeWorkspace"]["id"]))
        ids = {m["name"]: m["id"] for m in query(guest, "monitors", "all")}
        assignments = {c["address"]: (c["pid"], c["workspace"]["id"], c["monitor"]) for c in query(guest, "clients")}
        for x in (10100, 11720, 13300):
            for step_x in (x - 4, x - 2, x):
                cursor = query(host, "cursorpos")
                subprocess.run(["wlrctl", "pointer", "move", str(step_x - cursor["x"]), str(720 - cursor["y"])],
                               env=dict(env, WAYLAND_DISPLAY=outer["wl_socket"]), check=True, timeout=5)
                time.sleep(0.05)
            until(lambda: any(m["name"] == replacement and m["focused"] for m in query(guest, "monitors"))
                  and query(guest, "activewindow").get("address") == window["address"],
                  "Pointer did not focus the replacement output and its window")

        def parking(names):
            right = max(m["x"] + round((m["height"] if m["transform"] % 2 else m["width"]) / m["scale"])
                        for m in query(host, "monitors"))
            monitors = sorted((m for m in query(guest, "monitors", "all") if m["name"] in names), key=lambda m: m["x"])
            assert len(monitors) == len(names)
            assert all(not m["disabled"] and m["x"] > right and m["scale"] == 1 and m["transform"] == 0 for m in monitors)
            assert all(a["x"] + a["width"] <= b["x"] for a, b in zip(monitors, monitors[1:]))
            return [(m["id"], m["x"], m["y"], m["width"], m["height"]) for m in monitors]

        parked = parking([output])
        trace = runtime / "host-rpc.log"
        subprocess.run([sync], env=dict(watcher_env, HOST_RPC_TRACE=str(trace)), check=True, timeout=30)
        calls = [line.removeprefix("-q ") for line in trace.read_text().splitlines()]
        outer_calls = [line for line in calls if line.startswith(f"-i {host} ")]
        host_count = sum(c["pid"] == inner["pid"] and c["title"].startswith("aquamarine - split-") for c in query(host, "clients"))
        assert outer_calls.count(f"-i {host} -j monitors") == 1, outer_calls
        assert sum(line.startswith(f"-i {host} repl ") and ".place_host(" in line for line in outer_calls) == host_count, outer_calls
        assert len(outer_calls) == host_count + 1, outer_calls
        for reply, status in (("unexpected", 0), ("false", 17)):
            error_env = dict(watcher_env)
            error_env["BASH_FUNC_hyprctl%%"] = '''() {
                if [[ "${3-}" == repl ]]; then printf '%%s\\n' '%s'; return %d; fi
                "%s" "$@"
            }''' % (reply, status, hyprctl)
            failed = subprocess.run([sync], env=error_env, capture_output=True, text=True, timeout=30)
            assert failed.returncode != 0, "Transport failure was treated as a missing host"
            assert "Host placement failed:" in failed.stderr, failed
        print("PASS: native host PID/title isolation, checked transport, and one outer request per active/parked host")
        for _ in range(2):
            subprocess.run([sync], env=watcher_env, check=True, timeout=30)
            assert parking([output]) == parked, "Parking drifted on an unchanged topology"
        for x, y, scale, transform, width, height in ((20000, 0, 1, 0, 3440, 1440), (-5000, -200, 2, 1, 720, 1720)):
            command(host, "eval", 'hl.monitor({output="TEST-REPLACEMENT",position="%dx%d",scale=%d,transform=%d})'
                    % (x, y, scale, transform))
            until(lambda: any(m["name"] == replacement and (m["x"], m["y"], m["width"], m["height"]) == (x, y, width, height)
                              for m in query(guest, "monitors")))
            subprocess.run([sync], env=watcher_env, check=True, timeout=30)
            parking([output])
        connect("TEST-BIG-BOOTSTRAP-91", "3840x1200@60", "10000x0")
        sides = [output + "-left", output + "-right"]
        until(lambda: all(any(m["name"] == name and m["width"] == 1120 for m in query(guest, "monitors")) for name in sides))
        command(host, "eval", 'hl.monitor({output="TEST-BIG-BOOTSTRAP-91",mode="2560x1440@60"})')
        until(lambda: any(m["name"] == output and m["width"] == 2560 for m in query(guest, "monitors")))
        subprocess.run([sync], env=watcher_env, check=True, timeout=30)
        parking(sides)
        profile = ctx["config_home"] / "monique/outputs/monitors.lua"
        profile.parent.mkdir(parents=True)
        profile.write_text('hl.monitor({output="TEST-BIG-BOOTSTRAP-91",mode="2560x1440@60",position="11000x0",scale=1})\n'
                           'hl.monitor({output="TEST-REPLACEMENT",mode="3440x1440@60",position="-5000x-200",scale=2,transform=1})\n')
        command(host, "reload")
        until(lambda: any(m["name"] == output and m["x"] == 11000 for m in query(guest, "monitors")))
        subprocess.run([sync], env=watcher_env, check=True, timeout=30)
        parking(sides)
        assert all(next(m["id"] for m in query(guest, "monitors", "all") if m["name"] == name) == ident for name, ident in ids.items())
        assert {c["address"]: (c["pid"], c["workspace"]["id"], c["monitor"]) for c in query(guest, "clients")} == assignments
        assert watcher.poll() is None
        print("PASS: new-output bootstrap, replacement pointer routing, drift-free parking, expanded/rotated/scaled layouts, split retirement, EDID replug, reload, and window preservation")
