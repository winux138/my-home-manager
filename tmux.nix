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
      set -g update-environment "DISPLAY KRB5CCNAME MSYSTEM SSH_ASKPASS SSH_AUTH_SOCK SSH_AGENT_PID SSH_CONNECTION WINDOWID XAUTHORITY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR XDG_SESSION_TYPE"
      set -g extended-keys-format csi-u
    '';
  };
}
