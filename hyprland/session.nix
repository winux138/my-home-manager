{
  hyprlandPackage,
  innerConfig,
  outerConfig,
  pkgs,
  syncOutputs,
  wrap,
  xwayland,
}:
let
  hyprlandWrapped = wrap hyprlandPackage;
  xwaylandLauncher =
    pkgs.runCommand "hypr-xwayland"
      {
        nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
        meta.mainProgram = "Xwayland";
      }
      ''
        makeBinaryWrapper ${xwayland}/bin/Xwayland "$out/bin/Xwayland" \
          --prefix LD_LIBRARY_PATH : ${pkgs.sssd}/lib
      '';
  session = pkgs.writeShellApplication {
    name = "hypr-session";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.dbus
      pkgs.jq
      hyprlandWrapped
      xwaylandLauncher
      syncOutputs
    ];
    text = ''
      if [[ -z ''${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
        exec dbus-run-session -- "$0" "$@"
      fi
      state="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/hypr-session"
      mkdir -p "$state"
      export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:$PATH"

      outer_pid="" inner_pid="" sync_pid="" outer_instance="" inner_instance="" cleaning=false
      cleanup() {
        [[ $cleaning == false ]] || return
        cleaning=true
        set +e
        [[ -n $sync_pid ]] && kill "$sync_pid" 2>/dev/null
        [[ -n $inner_instance ]] && hyprctl -q -i "$inner_instance" dispatch 'hl.dsp.exit()'
        [[ -n $outer_instance ]] && hyprctl -q -i "$outer_instance" dispatch 'hl.dsp.exit()'
        [[ -n $sync_pid ]] && wait "$sync_pid" 2>/dev/null
        [[ -n $inner_pid ]] && wait "$inner_pid" 2>/dev/null
        [[ -n $outer_pid ]] && wait "$outer_pid" 2>/dev/null
      }
      trap cleanup EXIT INT TERM HUP

      wait_instance() {
        local pid=$1 instance
        for ((attempt = 0; attempt < 200; attempt++)); do
          instance=$(hyprctl -j instances 2>/dev/null |
            jq -r --argjson pid "$pid" '.[] | select(.pid == $pid) | .instance' 2>/dev/null || true)
          [[ -z $instance ]] || { printf '%s\n' "$instance"; return 0; }
          kill -0 "$pid" 2>/dev/null || return 1
          sleep 0.05
        done
        return 1
      }

      instance_socket() {
        hyprctl -j instances | jq -r --arg instance "$1" '.[] | select(.instance == $instance) | .wl_socket'
      }

      env AQ_NO_ATOMIC=1 AQ_NO_MODIFIERS=1 HYPRLAND_NO_SD_VARS=1 HYPRLAND_NO_SD_TARGET=1 \
        Hyprland --config "${outerConfig}" >"$state/outer.log" 2>&1 &
      outer_pid=$!
      outer_instance=$(wait_instance "$outer_pid") || { echo "outer Hyprland failed" >&2; exit 1; }
      outer_socket=$(instance_socket "$outer_instance")
      printf '%s\n' "$outer_pid" >"$state/outer.pid"
      printf '%s\n' "$outer_instance" >"$state/outer.instance"
      printf '%s\n' "$outer_socket" >"$state/outer.socket"

      env -u HYPRLAND_INSTANCE_SIGNATURE OUTER_HYPRLAND_INSTANCE="$outer_instance" \
        HYPR_AUTOSTART=1 WAYLAND_DISPLAY="$outer_socket" \
        Hyprland --config "${innerConfig}" >"$state/inner.log" 2>&1 &
      inner_pid=$!
      inner_instance=$(wait_instance "$inner_pid") || { echo "inner Hyprland failed" >&2; exit 1; }
      inner_socket=$(instance_socket "$inner_instance")
      printf '%s\n' "$inner_pid" >"$state/inner.pid"
      printf '%s\n' "$inner_instance" >"$state/inner.instance"
      printf '%s\n' "$inner_socket" >"$state/inner.socket"

      hypr-sync-outputs --watch >"$state/output-sync.log" 2>&1 &
      sync_pid=$!

      set +e
      wait -n "$outer_pid" "$inner_pid" "$sync_pid"
    '';
  };
  waylandSession = pkgs.writeTextDir "share/wayland-sessions/hyprland-split.desktop" ''
    [Desktop Entry]
    Name=Hyprland (Split)
    Comment=Nested Hyprland session with 3-way ultrawide split
    Exec=${pkgs.lib.getExe session}
    Type=Application
    DesktopNames=Hyprland
  '';
in
{
  inherit
    hyprlandWrapped
    session
    waylandSession
    xwaylandLauncher
    ;
}
