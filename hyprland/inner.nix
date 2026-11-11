{
  autostartCommands ? [ ],
  hyprfocusPlugin,
  hyprsplitLua,
  innerRuntime,
  lib,
}:
let
  toLua = lib.generators.toLua { };
  lua = lib.generators.mkLuaInline;
  mod = "SUPER";
  terminal = "foot";
  bind = key: action: [
    "${mod} + ${key}"
    (lua action)
  ];
  sync = action: "runtime.sync_after(${action})";
  exec = command: "hl.dsp.exec_cmd(${toLua command})";
  mouse = key: action: (bind key action) ++ [ { mouse = true; } ];
  animation =
    leaf: speed: extra:
    {
      inherit leaf speed;
      enabled = true;
      bezier = "default";
    }
    // extra;
  monitor = {
    output = "";
    mode = "preferred";
    position = "auto";
    scale = 1;
  };
  environment = {
    XDG_SESSION_TYPE = "wayland";
    XCURSOR_SIZE = "18";
    HYPRCURSOR_SIZE = "18";
  };
  settings = {
    general = {
      gaps_in = 4;
      gaps_out = 8;
      border_size = 2;
      col.active_border = {
        colors = [
          "#8ac926ff"
          "#1982c4ff"
        ];
        angle = 0;
      };
      col.inactive_border = "#3c4048ff";
    };
    decoration = {
      rounding = 6;
      active_opacity = 1.0;
      blur.enabled = true;
      blur.size = 3;
    };
    animations.enabled = true;
    cursor.no_hardware_cursors = 1;
    dwindle.force_split = 2;
    dwindle.preserve_split = true;
    input = {
      kb_layout = "us";
      follow_mouse = 1;
      natural_scroll = false;
      sensitivity = 0.0;
    };
    xwayland.enabled = true;
    misc.disable_hyprland_logo = true;
    misc.force_default_wallpaper = 0;
  };
  curve = {
    type = "bezier";
    points = [
      [
        0.05
        0.9
      ]
      [
        0.1
        1.05
      ]
    ];
  };
  animations = [
    (animation "windows" 3 { bezier = "myBezier"; })
    {
      leaf = "windowsIn";
      enabled = false;
    }
    (animation "windowsOut" 3 { style = "popin 80%"; })
    {
      leaf = "border";
      enabled = false;
    }
    {
      leaf = "borderangle";
      enabled = false;
    }
    (animation "fade" 3 { })
    {
      leaf = "fadeIn";
      enabled = false;
    }
    (animation "workspaces" 4 { })
  ];
  bindings = [
    (bind "SHIFT + G" (exec "hypr-screenshot"))
    (bind "P" (exec "caelestia shell drawers toggle launcher"))
    (bind "Return" (exec terminal))
    (bind "SHIFT + L" (exec "hypr-lock"))
    (bind "CTRL + G" (exec "hypr-gather-windows"))
    (bind "C" "hl.dsp.window.close()")
    (bind "S" "hl.dsp.workspace.toggle_special('magic')")
    (bind "SHIFT + S" "hl.dsp.window.move({ workspace = 'special:magic' })")
    (bind "H" (sync "hl.dsp.focus({ direction = 'left' })"))
    (bind "J" (sync "hl.dsp.focus({ direction = 'down' })"))
    (bind "K" (sync "hl.dsp.focus({ direction = 'up' })"))
    (bind "L" (sync "hl.dsp.focus({ direction = 'right' })"))
    (bind "SHIFT + J" (sync "hl.dsp.window.move({ direction = 'down' })"))
    (bind "SHIFT + K" (sync "hl.dsp.window.move({ direction = 'up' })"))
    (bind "comma" (sync "runtime.monitor_action(-1, false)"))
    (bind "period" (sync "runtime.monitor_action(1, false)"))
    (bind "SHIFT + comma" (sync "runtime.monitor_action(-1, true)"))
    (bind "SHIFT + period" (sync "runtime.monitor_action(1, true)"))
  ]
  ++ lib.concatMap (i: [
    (bind "code:${toString (i + 9)}" (sync "hyprsplit.dsp.focus({ workspace = ${toString i} })"))
    (bind "SHIFT + code:${toString (i + 9)}" (
      sync "hyprsplit.dsp.window.move({ workspace = ${toString i} })"
    ))
  ]) (lib.range 1 9)
  ++ [
    (mouse "mouse:272" "hl.dsp.window.drag()")
    (mouse "mouse:273" "hl.dsp.window.resize()")
    (bind "F" "hl.dsp.window.fullscreen({ mode = 'fullscreen' })")
    (bind "SHIFT + Escape" "hl.dsp.exit()")
  ];
in
''
  local hyprsplit = dofile(${toLua "${hyprsplitLua}"})
  hl.plugin.load(${toLua "${hyprfocusPlugin}"})
  local runtime = dofile(${toLua "${innerRuntime}"})

  hl.monitor(${toLua monitor})
  ${lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "hl.env(${toLua name}, ${toLua value})") environment
  )}
  hl.config(${toLua settings})
  hl.curve("myBezier", ${toLua curve})
  ${lib.concatMapStringsSep "\n" (spec: "hl.animation(${toLua spec})") animations}

  ${lib.concatMapStringsSep "\n" (
    args: "hl.bind(${lib.concatMapStringsSep ", " toLua args})"
  ) bindings}

  runtime.autostart(${toLua autostartCommands})
''
