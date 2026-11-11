{
  blueLightLua,
  hyprlandPackage,
  moniquePackage,
  pkgs,
  unstable,
  wrap,
}:
let
  blueLight = pkgs.writeShellApplication {
    name = "blue-light";
    runtimeInputs = [
      pkgs.coreutils
      hyprlandPackage
    ];
    text = ''
      : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}"
      [[ $# == 1 ]] || { echo "usage: blue-light <1000-20000|off>" >&2; exit 2; }
      state="$XDG_RUNTIME_DIR/hypr-session"
      instance=$(<"$state/outer.instance")
      : "''${instance:?outer compositor instance is not set}"

      if [[ $1 == off ]]; then
        result=$(hyprctl -i "$instance" eval "dofile('${blueLightLua}').apply(nil)")
        [[ $result == ok ]] || { printf '%s\n' "$result" >&2; exit 1; }
        printf 'Blue-light filter disabled.\n'
        exit 0
      fi

      [[ $1 =~ ^[0-9]+$ ]] || { echo "temperature must be an integer or 'off'" >&2; exit 2; }
      kelvin=$1
      (( kelvin >= 1000 && kelvin <= 20000 )) || {
        echo "temperature must be between 1000 and 20000 K" >&2
        exit 2
      }

      install -d -m 700 -- "$state"
      shader="$state/blue-light-$kelvin.frag"
      [[ $shader != *"'"* ]] || { echo "runtime path contains an unsupported quote" >&2; exit 1; }
      result=$(hyprctl -i "$instance" eval "dofile('${blueLightLua}').apply($kelvin, '$shader')")
      [[ $result == ok ]] || { printf '%s\n' "$result" >&2; exit 1; }
      printf 'Blue-light filter set to %s K.\n' "$kelvin"
    '';
  };
  detectMonitor = pkgs.writeShellApplication {
    name = "detect-monitor";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if (( EUID != 0 )); then
        [[ -x /usr/bin/sudo ]] || { echo "/usr/bin/sudo is unavailable" >&2; exit 1; }
        exec /usr/bin/sudo -- "$0" "$@"
      fi
      connectors=(/sys/class/drm/card*-DP-*/status)
      [[ -e ''${connectors[0]} ]] || { echo "no DisplayPort connectors found" >&2; exit 1; }
      printf 'Probing disconnected DisplayPort connectors for up to 90 seconds.\n'
      SECONDS=0
      while (( SECONDS < 90 )); do
        for status in "''${connectors[@]}"; do
          state=$(<"$status")
          if [[ $state == disconnected ]]; then
            printf 'detect\n' >"$status" || continue
            state=$(<"$status")
          fi
          if [[ $state == connected ]]; then
            printf '%s connected after %ss.\n' "''${status%/status}" "$SECONDS"
            exit 0
          fi
        done
        sleep 2
      done
      printf 'No DisplayPort connector recovered within %ss.\n' "$SECONDS" >&2
      exit 1
    '';
  };
  chrome =
    name: flags:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        [[ -x /usr/bin/google-chrome ]] || { echo "/usr/bin/google-chrome is unavailable" >&2; exit 1; }
        : "''${HOME:?HOME is not set}"
        exec /usr/bin/google-chrome --user-data-dir="$HOME/.config/google-chrome" ${pkgs.lib.escapeShellArgs flags} "$@"
      '';
    };
  companyChrome = chrome "company-chrome" [
    "--ozone-platform=wayland"
    "--site-per-process"
    "--enable-features=AcceleratedVideoEncoder"
  ];
  defaultChrome = chrome "default-chrome" [ ];
  chromeDesktop =
    {
      comment,
      desktopName,
      name,
      package,
    }:
    pkgs.makeDesktopItem {
      inherit comment desktopName name;
      exec = "${pkgs.lib.getExe package} %U";
      icon = "google-chrome";
      categories = [
        "Network"
        "WebBrowser"
      ];
      terminal = false;
      startupNotify = true;
    };
  blueLightDesktop =
    {
      argument,
      desktopName,
      name,
    }:
    pkgs.makeDesktopItem {
      inherit desktopName name;
      exec = "${pkgs.lib.getExe blueLight} ${argument}";
      icon = "preferences-desktop-display";
      categories = [ "Settings" ];
      keywords = [
        "blue light"
        "color temperature"
        "night light"
      ];
      terminal = false;
    };
  sattyWrapped = wrap pkgs.satty;
  screenshot = pkgs.writeShellApplication {
    name = "hypr-screenshot";
    runtimeInputs = [
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      sattyWrapped
    ];
    text = ''
      state="''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/hypr-session"
      if [[ -s $state/inner.socket ]]; then
        WAYLAND_DISPLAY=$(<"$state/inner.socket")
      fi
      : "''${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is not set}"
      export WAYLAND_DISPLAY GDK_BACKEND=wayland
      geometry=$(slurp </dev/null)
      grim -g "$geometry" -t ppm - | satty \
        --filename - --fullscreen=current-screen --copy-command wl-copy \
        --early-exit=all "$@"
    '';
  };
  desktopEntries = pkgs.symlinkJoin {
    name = "hypr-desktop-entries";
    paths = [
      (blueLightDesktop {
        name = "blue-light-2500";
        desktopName = "Blue Light - 2500 K";
        argument = "2500";
      })
      (blueLightDesktop {
        name = "blue-light-off";
        desktopName = "Blue Light - Off";
        argument = "off";
      })
      (chromeDesktop {
        name = "company-chrome";
        desktopName = "Company Chrome";
        comment = "Company-managed Chrome with accelerated Wayland flags";
        package = companyChrome;
      })
      (chromeDesktop {
        name = "default-chrome";
        desktopName = "Default Chrome";
        comment = "Company-managed Chrome with default flags";
        package = defaultChrome;
      })
      (pkgs.makeDesktopItem {
        name = "hypr-screenshot";
        desktopName = "Screenshot (Satty)";
        comment = "Select a region and annotate the screenshot";
        exec = pkgs.lib.getExe screenshot;
        icon = "${pkgs.satty}/share/icons/hicolor/scalable/apps/satty.svg";
        categories = [
          "Graphics"
          "Utility"
        ];
        terminal = false;
      })
    ];
  };
  caelestiaPackage = wrap (
    (unstable.caelestia-shell.override { hyprland = hyprlandPackage; }).overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace services/Hypr.qml \
          --replace-fail 'return Hyprland.monitorFor(screen);' \
            'return monitors.values.find(m => m.name === screen?.name) ?? null;'
      '';
    })
  );
  caelestiaSettings = {
    general = {
      apps = {
        browser = [ (pkgs.lib.getExe companyChrome) ];
        terminal = [ "foot" ];
      };
      idle = {
        lockBeforeSleep = false;
        timeouts = [ ];
      };
    };
    launcher = {
      enabled = true;
      favouriteApps = [ "^company-chrome(\\.desktop)?$" ];
      hiddenApps = [ "^google-chrome(\\.desktop)?$" ];
    };
    lock.enabled = false;
    session.enabled = false;
  };
  caelestiaLauncher = pkgs.writeShellApplication {
    name = "hypr-caelestia";
    runtimeInputs = [
      caelestiaPackage
      unstable.caelestia-cli
      pkgs.coreutils
    ];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
      mkdir -p "''${XDG_CACHE_HOME:-$HOME/.cache}/caelestia" "$state_dir"
      if [[ ! -e $state_dir/scheme.json ]]; then
        caelestia scheme set -n caelestia -f default -m light || true
      fi
      exec caelestia-shell "$@"
    '';
  };
  moniqueWrapped = wrap moniquePackage;
  moniqueSettings = (pkgs.formats.json { }).generate "monique-settings.json" {
    hypr_config_format = "lua";
    update_greetd = false;
    update_sddm = false;
    use_port_names = false;
  };
  moniqueLauncher = pkgs.writeShellApplication {
    name = "monique";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}"
      instance_file="$XDG_RUNTIME_DIR/hypr-session/outer.instance"
      [[ -s $instance_file ]] || { echo "outer Hyprland instance is unavailable" >&2; exit 1; }
      HYPRLAND_INSTANCE_SIGNATURE=$(<"$instance_file")
      export HYPRLAND_INSTANCE_SIGNATURE
      config_root="''${XDG_CONFIG_HOME:-$HOME/.config}/monique"
      mkdir -p "$config_root/outputs"
      settings_file="$config_root/settings.json"
      if [[ -e $settings_file ]]; then
        tmp=$(mktemp "$config_root/.settings.XXXXXX")
        jq '.hypr_config_format = "lua" | .update_greetd = false | .update_sddm = false | .use_port_names = false' \
          "$settings_file" >"$tmp"
        mv -f "$tmp" "$settings_file"
      else
        install -m 644 ${moniqueSettings} "$settings_file"
      fi
      exec ${pkgs.lib.getExe moniqueWrapped} --config-dir "$config_root/outputs" "$@"
    '';
  };
  monitorEditor = pkgs.symlinkJoin {
    name = "hypr-monique";
    paths = [ moniquePackage ];
    postBuild = ''
      rm "$out/bin/monique"
      ln -s ${moniqueLauncher}/bin/monique "$out/bin/monique"
    '';
  };
  safeEyes = wrap (
    pkgs.safeeyes.overridePythonAttrs (old: {
      dependencies = (old.dependencies or [ ]) ++ [ pkgs.python3Packages.pywayland ];
    })
  );
in
{
  inherit
    blueLight
    caelestiaLauncher
    caelestiaPackage
    caelestiaSettings
    companyChrome
    defaultChrome
    desktopEntries
    detectMonitor
    monitorEditor
    safeEyes
    screenshot
    ;
}
