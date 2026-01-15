{ lib, pkgs, ... }:
{

  programs.tmux = {
    enable = true;
    clock24 = true;
    mouse = true;
    keyMode = "vi";
    baseIndex = 1;
    customPaneNavigationAndResize = true;
    escapeTime = 0;
    extraConfig = ''
      set -g default-terminal "st-256color"
      set -ag terminal-overrides ",st-256color:RGB"
    '';
  };
}
