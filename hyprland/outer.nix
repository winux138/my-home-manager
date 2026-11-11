{
  innerRuntime,
  lib,
  outerRuntime,
}:
let
  toLua = lib.generators.toLua { };
  lua = lib.generators.mkLuaInline;
  monitor = {
    output = "";
    mode = "preferred";
    position = "auto";
    scale = 1;
  };
  settings = {
    general = {
      gaps_in = 0;
      gaps_out = 0;
      border_size = 0;
    };
    decoration = {
      rounding = 0;
      screen_shader = "blue-light.frag";
      shadow.enabled = false;
      blur.enabled = false;
    };
    animations.enabled = false;
    input = {
      follow_mouse = 1;
      natural_scroll = false;
      touchpad = {
        natural_scroll = true;
        disable_while_typing = true;
      };
    };
    xwayland.enabled = false;
    misc = {
      disable_hyprland_logo = true;
      force_default_wallpaper = 0;
    };
  };
  device = {
    name = "pixart-usb-optical-mouse";
    sensitivity = -1;
    natural_scroll = false;
  };
  bindOptions = {
    dont_inhibit = true;
  };
  bindings = [
    [
      "CTRL + ALT + Return"
      (lua "runtime.toggle_debug_terminal")
      bindOptions
    ]
    [
      "CTRL + ALT + SHIFT + Escape"
      (lua "hl.dsp.exit()")
      bindOptions
    ]
  ];
  swipeDistance = 150;
  gesture = {
    fingers = 3;
    direction = "horizontal";
    action = lua "runtime.workspace_swipe(${toLua "${innerRuntime}"}, ${toLua swipeDistance})";
  };
in
''
  local runtime = dofile(${toLua "${outerRuntime}"})

  runtime.watch_layout()
  hl.monitor(${toLua monitor})
  runtime.load_monitors()
  hl.config(${toLua settings})
  hl.device(${toLua device})

  ${lib.concatMapStringsSep "\n" (
    args: "hl.bind(${lib.concatMapStringsSep ", " toLua args})"
  ) bindings}
  hl.gesture(${toLua gesture})
''
