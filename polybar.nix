{ lib, pkgs, ... }:
let
  ac = "#1E88E5";
  mf = "#383838";

  bg = "#00000000";
  fg = "#FFFFFF";

  # Colored
  primary = "#91ddff";

  # Dark
  secondary = "#141228";

  # Colored (light)
  tertiary = "#65b2ff";

  # white
  quaternary = "#ecf0f1";

  # middle gray
  quinternary = "#20203d";

  # Red
  urgency = "#e74c3c";
in
{
  services.polybar = {
    enable = true;

    script = "polybar bar &";

    config = {
      "bar/top" = {
        bottom = false;
        width = "100%";
        height = 32;
        modules-center = "pulseaudio";
        modules-right = "systray";
      };

      "module/title" = {
        type = "internal/xwindow";
        format = "<label>";
        format-foreground = secondary;
        label = "title";
        label-maxlen = 70;
      };

      "module/systray" = {
        type = "internal/tray";
      };

      "module/pulseaudio" = {
        type = "internal/pulseaudio";
      };
    };
  };
}
