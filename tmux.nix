{ lib, pkgs, ... }:
{

  programs.tmux = {
    enable = true;
    shell = "${pkgs.fish}/bin/fish";
    clock24 = true;
    mouse = true;
    keyMode = "vi";
    baseIndex = 1;
    customPaneNavigationAndResize = true;
    escapeTime = 0;
    extraConfig = ''
      set -g default-terminal "st-256color"
      set -ag terminal-overrides ",st-256color:RGB"
      set -g extended-keys always
      set -as terminal-features 'xterm*:extkeys'
    '';
  };
}
