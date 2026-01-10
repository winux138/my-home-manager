{ lib, pkgs, ... }:
let
  neovimConfig = import ./neovim.nix { inherit lib pkgs; };
  gitConfig = import ./git.nix { inherit lib pkgs; };
  tmuxConfig = import ./tmux.nix { inherit lib pkgs; };
in
{
  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

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

      # fonts
      font-awesome
      dina-font
      liberation_ttf
      mplus-outline-fonts.githubRelease
      nerd-fonts.iosevka
      nerd-fonts.symbols-only
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      # proggyfonts
    ];

    username = "ju";
    homeDirectory = "/home/ju";

    stateVersion = "25.11";
  };

  imports = [
    neovimConfig
    gitConfig
    tmuxConfig
  ];
}
