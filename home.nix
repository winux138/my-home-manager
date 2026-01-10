{ lib, pkgs, ... }:
{
  programs.home-manager.enable = true;

  home = {
    packages = with pkgs; [
      kitty
      keepassxc

      neovim
      lazygit
      helix

      fd
      ripgrep
      ouch
      tmux
      fastfetch
      bat
      bottom
      htop
      fzf
      eza
      dust
      tree
      opencode
      curl
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
