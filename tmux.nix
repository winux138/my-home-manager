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
  };
}
