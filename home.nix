{ lib, pkgs, ... }:
let
in
{
  imports = [
    ./neovim.nix
    ./git.nix
    ./tmux.nix
    ./polybar.nix
  ];

  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  services.safeeyes.enable = true;
  services.snixembed = {
    enable = true;

    beforeUnits = [
      # https://github.com/slgobinath/SafeEyes/wiki/How-to-install-backend-for-Safe-Eyes-tray-icon
      "safeeyes.service"
    ];
  };

  home = {
    packages = with pkgs; [
      kitty
      keepassxc
      # quickshell
      polybar
      brightnessctl
      flameshot

      xclip
      arandr
      lazygit
      helix
      direnv

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
}
