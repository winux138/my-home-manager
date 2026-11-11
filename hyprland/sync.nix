{
  hyprlandPackage,
  innerRuntime,
  outerRuntime,
  pkgs,
}:
let
  outputId = pkgs.writeShellApplication {
    name = "hypr-output-id";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      [[ $# == 1 && -n $1 ]] || { echo "usage: hypr-output-id <EDID description>" >&2; exit 2; }
      printf 'edid-%s\n' "$(printf %s "$1" | sha256sum | cut -c1-12)"
    '';
  };
  syncOutputs = pkgs.writeShellApplication {
    name = "hypr-sync-outputs";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.util-linux
      pkgs.socat
      hyprlandPackage
      outputId
    ];
    text = ''
      : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}"
      state="$XDG_RUNTIME_DIR/hypr-session"
      [[ -s $state/outer.instance && -s $state/inner.instance && -s $state/inner.pid ]] || exit 0
      outer=$(<"$state/outer.instance")
      case "''${1:-}" in
        --watch)
          exec socat -u "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$outer/.socket2.sock" "EXEC:$0 --events,nofork"
          ;;
        --events)
          "$0"
          printf 'watching output lifecycle\n' >&2
          while IFS= read -r event; do
            case "$event" in
              monitoradded*|monitorremoved*|configreloaded*|"custom>>hypr-output-layout"|"openwindow>>"*",aquamarine,"*|"windowtitlev2>>"*",aquamarine - split-"*)
                "$0" || printf 'output reconciliation failed; waiting for the next event\n' >&2
                ;;
            esac
          done
          exit 0
          ;;
      esac

      exec 9>"$state/output-sync.lock"
      flock 9
      outer=$(<"$state/outer.instance")
      inner=$(<"$state/inner.instance")
      inner_pid=$(<"$state/inner.pid")
      map="$state/output-map.json"
      [[ -s $map ]] || printf '{}\n' >"$map"

      inner_has_output() {
        hyprctl -i "$inner" -j monitors all |
          jq -e --arg output "$1" 'any(.[]; .name == $output)' >/dev/null
      }

      place_host() {
        local result
        if result=$(hyprctl -i "$outer" repl \
          "dofile('${outerRuntime}').place_host('$1', $inner_pid, $2, $3)") && [[ $result == true || $result == false ]]; then
          printf '%s\n' "$result"
        else
          printf 'Host placement failed: %s\n' "$result" >&2
          return 1
        fi
      }

      created=0
      mapped=0
      wanted=()
      parking_x=
      place_output() {
        local output=$1 x=$2 y=$3 width=$4 height=$5 placed position mode
        wanted+=("$output")
        (( width > 0 && height > 0 )) || return 0
        printf -v position '%sx%s' "$x" "$y"
        placed=$(place_host "$output" "$workspace" "{ x = $x, y = $y, width = $width, height = $height }")
        if [[ $placed == false ]]; then
          printf -v mode '%sx%s@60' "$width" "$height"
          hyprctl -q -i "$inner" eval \
            "hl.monitor({ output = '$output', mode = '$mode', position = '$position', scale = 1, transform = 0, disabled = false })"
          if ! inner_has_output "$output"; then
            hyprctl -q -i "$inner" output create wayland "$output"
            ((created += 1))
          fi
          return 0
        fi

        hyprctl -q -i "$inner" eval \
          "hl.monitor({ output = '$output', mode = 'preferred', position = '$position', scale = 1, transform = 0 })"
        ((mapped += 1))
      }

      monitors=$(hyprctl -i "$outer" -j monitors)
      while IFS= read -r monitor; do
        identity=$(jq -r 'if (.description // "") != "" then .description else "port:" + .name end' <<<"$monitor")
        output=$(jq -r --arg identity "$identity" '.[$identity] // empty' "$map")
        if [[ -z $output ]]; then
          output="split-$(hypr-output-id "$identity")"
          tmp=$(mktemp "$state/.output-map.XXXXXX")
          jq --arg identity "$identity" --arg output "$output" '.[$identity] = $output' "$map" >"$tmp"
          mv -f "$tmp" "$map"
        fi

        read -r x y width height workspace split < <(jq -r '
          [.x, .y,
           (if (.transform % 2) == 1 then .height else .width end / .scale | round),
           (if (.transform % 2) == 1 then .width else .height end / .scale | round),
           .activeWorkspace.id,
           ((.name | startswith("eDP-") | not) and .width == 3840 and .height == 1200
            and .transform == 0 and .scale == 1)] | @tsv
        ' <<<"$monitor")
        if [[ -z $parking_x ]] || (( x + width > parking_x )); then
          parking_x=$((x + width))
        fi
        if [[ $split == true ]]; then
          place_output "$output-left" "$x" "$y" 1120 "$height"
          place_output "$output" "$((x + 1120))" "$y" 1600 "$height"
          place_output "$output-right" "$((x + 2720))" "$y" 1120 "$height"
        else
          place_output "$output" "$x" "$y" "$width" "$height"
        fi
      done < <(jq -c 'sort_by(.id)[]' <<<"$monitors")

      if (( ''${#wanted[@]} > 0 )); then
        parking_x=$((parking_x + 256))
        parked=$(hyprctl -i "$inner" -j monitors all | jq -r --slurpfile map "$map" '
          [$map[0][] | ., . + "-left", . + "-right"] as $managed |
          sort_by(.id)[] | select(.name as $name | $managed | index($name)) |
          [.name, (if (.transform % 2) == 1 then .height else .width end / .scale | ceil),
           .scale, .transform] | @tsv
        ')
        while IFS=$'\t' read -r output width scale transform; do
          [[ -n $output && " ''${wanted[*]} " != *" $output "* ]] || continue
          place_host "$output" "'special:hypr-disconnected'" nil >/dev/null
          printf -v position '%sx0' "$parking_x"
          hyprctl -q -i "$inner" eval \
            "hl.monitor({ output = '$output', position = '$position', scale = $scale, transform = $transform })"
          parking_x=$((parking_x + width))
        done <<<"$parked"
      fi

      if (( mapped > 0 )); then
        default_output=$(hyprctl -i "$inner" -j monitors all |
          jq -r 'first(.[] | select(.name | test("^WAYLAND-[0-9]+$")) | .name) // empty')
        [[ -z $default_output ]] || hyprctl -q -i "$inner" output remove "$default_output"
      fi
      printf 'created %d and reconciled %d split output(s)\n' "$created" "$mapped"
    '';
  };
  gatherWindows = pkgs.writeShellApplication {
    name = "hypr-gather-windows";
    runtimeInputs = [
      pkgs.jq
      pkgs.util-linux
      hyprlandPackage
    ];
    text = ''
      if [[ ''${1:-} == --help ]]; then
        printf 'Usage: hypr-gather-windows\nGather windows from disconnected monitors into the current workspace and remove their virtual outputs.\n'
        exit 0
      fi
      [[ $# == 0 ]] || { echo "usage: hypr-gather-windows" >&2; exit 2; }
      state="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/hypr-session"
      exec 9>"$state/output-sync.lock"
      flock 9
      outer=$(<"$state/outer.instance")
      inner=$(<"$state/inner.instance")
      inner_pid=$(<"$state/inner.pid")
      monitors=$(hyprctl -i "$outer" -j monitors all)
      hosts=$(hyprctl -i "$outer" -j clients)
      shown=$(jq -nr --argjson monitors "$monitors" --argjson hosts "$hosts" --argjson pid "$inner_pid" '
        [$monitors[] | select(.disabled != true and .dpmsStatus != false) |
          .activeWorkspace.address, .specialWorkspace.address | select(. != null and . != "")] as $visible |
        $hosts | map(select(.pid == $pid and .mapped and (.hidden | not)) |
          select(.workspace.address as $workspace | $visible | index($workspace)) |
          .title | ltrimstr("aquamarine - ")) | unique |
        map("[" + tojson + "] = true") | "{" + join(",") + "}"
      ')
      disconnected=$(jq -nc --argjson monitors "$monitors" --slurpfile map "$state/output-map.json" '
        [$monitors[] | if (.description // "") != "" then .description else "port:" + .name end] as $connected |
        [$map[0] | to_entries[] | select(.key as $identity | $connected | index($identity) | not) |
          .value | ., . + "-left", . + "-right"]
      ')
      outputs=$(hyprctl -i "$inner" -j monitors all | jq -c --argjson disconnected "$disconnected" '
        [.[] | select(.name as $name | $disconnected | index($name)) | .name]
      ')
      [[ $outputs != '[]' ]] || { printf 'No disconnected virtual outputs to recover.\n'; exit 0; }
      disconnected=$(jq -r 'map("[" + tojson + "] = true") | "{" + join(",") + "}"' <<<"$outputs")
      cursor=$(hyprctl -i "$inner" -j cursorpos | jq -r '"{ x = \(.x), y = \(.y) }"')
      focus=$(hyprctl -i "$inner" repl \
        "dofile('${innerRuntime}').gather_windows($shown, $disconnected)") || {
        printf 'Window transfer failed: %s\n' "$focus" >&2
        exit 1
      }
      [[ $focus =~ ^([0-9]+)\ (0x[0-9a-f]+|none)\ ([0-9]+)$ ]] || { printf '%s\n' "$focus" >&2; exit 1; }
      target=''${BASH_REMATCH[1]}
      focused=''${BASH_REMATCH[2]}
      gathered=''${BASH_REMATCH[3]}
      while IFS= read -r output; do
        if ! hyprctl -i "$outer" -j monitors all | jq -e --argjson before "$monitors" '
          def identities: map(if (.description // "") != "" then .description else "port:" + .name end) | sort;
          identities == ($before | identities)
        ' >/dev/null; then
          printf 'Monitor connections changed or their query failed. Run recovery again.\n' >&2
          exit 1
        fi
        if ! result=$(hyprctl -i "$inner" output remove "$output") || [[ $result != ok ]]; then
          printf 'Output removal failed: %s\n' "$result" >&2
          exit 1
        fi
      done < <(jq -r '.[]' <<<"$outputs")
      result=$(hyprctl -i "$inner" repl \
        "dofile('${innerRuntime}').restore_focus($target, '$focused', $cursor)") || {
        printf 'Focus restoration failed: %s\n' "$result" >&2
        exit 1
      }
      [[ $result == true ]] || { printf 'Focus restoration failed: %s\n' "$result" >&2; exit 1; }
      hyprctl -q -i "$outer" dispatch "hl.dsp.cursor.move($cursor)"
      printf 'Gathered %s window(s) and removed %s disconnected virtual output(s).\n' "$gathered" "$(jq length <<<"$outputs")"
    '';
  };
in
{
  inherit
    gatherWindows
    outputId
    syncOutputs
    ;
}
