{ lib, pkgs, ... }:
{
  programs.home-manager.enable = true;

  home = {
    packages = with pkgs; [
      neovim
      lazygit

      fd
      ripgrep
      ouch
      tmux
    ];

    username = "ju";
    homeDirectory = "/home/ju";

    stateVersion = "25.11";
  };

    programs.git = {
      enable = true;
      settings.user.name = "ju";
      settings.user.email = "thomas.julien@protonmail.com";
    };
}
