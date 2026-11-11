{
  config,
  inputs,
  pkgs,
  unstable,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  wrap = config.lib.nixGL.wrap;
  hyprlandPackage = inputs.hyprland.packages.${system}.hyprland;
  hyprfocus = inputs.hyprland-plugins.packages.${system}.hyprfocus;
  xwayland = inputs.hyprland.inputs.nixpkgs.legacyPackages.${system}.xwayland;
  moniquePackage = inputs.monique.packages.${system}.default;

  hyprsplitLua = pkgs.runCommand "hyprsplit-lua" { } ''
    install -Dm444 ${pkgs.hyprlandPlugins.hyprsplit.src}/init.lua \
      "$out/share/hyprsplit/init.lua"
  '';

  desktop = import ./desktop.nix {
    inherit
      hyprlandPackage
      moniquePackage
      pkgs
      unstable
      wrap
      ;
    blueLightLua = ./blue-light.lua;
  };

  lock = import ./lock.nix { inherit pkgs wrap; };

  autostartCommands = [
    "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE"
    (pkgs.lib.getExe desktop.caelestiaLauncher)
    "env GDK_BACKEND=wayland ${pkgs.lib.getExe desktop.safeEyes}"
    "foot"
  ];

  innerLua = pkgs.writeText "inner.lua" (
    import ./inner.nix {
      inherit (pkgs) lib;
      inherit autostartCommands;
      hyprfocusPlugin = "${hyprfocus}/lib/libhyprfocus.so";
      hyprsplitLua = "${hyprsplitLua}/share/hyprsplit/init.lua";
      innerRuntime = ./inner-runtime.lua;
    }
  );
  outerLua = pkgs.writeText "outer.lua" (
    import ./outer.nix {
      inherit (pkgs) lib;
      innerRuntime = ./inner-runtime.lua;
      outerRuntime = ./outer-runtime.lua;
    }
  );
  configBundle = pkgs.runCommand "hyprland-config" { } ''
    install -Dm444 ${innerLua} "$out/inner.lua"
    install -Dm444 ${./inner-runtime.lua} "$out/inner-runtime.lua"
    install -Dm444 ${outerLua} "$out/outer.lua"
    install -Dm444 ${./outer-runtime.lua} "$out/outer-runtime.lua"
    install -Dm444 ${./blue-light.frag} "$out/blue-light.frag"
  '';

  sync = import ./sync.nix {
    inherit hyprlandPackage pkgs;
    innerRuntime = "${configBundle}/inner-runtime.lua";
    outerRuntime = "${configBundle}/outer-runtime.lua";
  };

  session = import ./session.nix {
    inherit
      hyprlandPackage
      pkgs
      wrap
      xwayland
      ;
    innerConfig = "${configBundle}/inner.lua";
    outerConfig = "${configBundle}/outer.lua";
    syncOutputs = sync.syncOutputs;
  };
in
{
  xdg.configFile."caelestia/shell.json".text = builtins.toJSON desktop.caelestiaSettings;

  home.packages = [
    unstable.caelestia-cli
    desktop.blueLight
    desktop.caelestiaLauncher
    desktop.caelestiaPackage
    desktop.companyChrome
    desktop.defaultChrome
    desktop.desktopEntries
    desktop.detectMonitor
    desktop.monitorEditor
    desktop.safeEyes
    desktop.screenshot
    lock.checkAuth
    lock.lock
    lock.setPassword
    pkgs.grim
    pkgs.slurp
    pkgs.socat
    pkgs.wayland-utils
    session.hyprlandWrapped
    session.session
    session.waylandSession
    session.xwaylandLauncher
    sync.gatherWindows
    sync.outputId
    sync.syncOutputs
  ];
}
