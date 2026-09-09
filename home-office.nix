{
  inputs,
  # lib,
  config,
  pkgs,
  nixgl,
  ...
}:
let
  wrap = config.lib.nixGL.wrap;
in
{
  imports = [
    ./fish.nix
    ./git.nix
    ./helix.nix
    ./kitty.nix
    ./tmux.nix
    ./polybar.nix
    ./pi.nix
  ];

  programs.home-manager.enable = true;
  nixpkgs.config.allowUnfree = true;

  targets.genericLinux.nixGL = {
    packages = nixgl.packages;
    defaultWrapper = "mesa";
    installScripts = [ "mesa" ]; # provides `nixGLMesa` command for manual use (e.g. picom)
  };

  programs.bash.enable = true;
  programs.bash.initExtra = ''
    eval "$(direnv hook bash)"
  '';

  fonts.fontconfig.enable = true;

  programs.kitty.package = wrap pkgs.kitty;

  programs.foot = {
    enable = true;
    settings = {
      main = {
        term = "xterm-256color";
        font = "Iosevka Nerd Font:size=11";
      };
    };
  };

  programs.firefox = {
    enable = true;
    package = wrap pkgs.firefox;
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    profiles.thomaj81.extensions.packages = with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
      ublock-origin
      consent-o-matic
      tridactyl
    ];
  };

  home = {
    packages = (with pkgs; [
      # proprietary / work related
      # vscode

      gh

      meld
      plantuml
      pandoc
      (wrap krita)
      keepassxc
      (wrap quickshell)
      polybar
      brightnessctl
      flameshot
      dust

      xclip
      arandr
      direnv
      zathura

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
      curl
      rsync

      direnv

      # fonts
      font-awesome
      dina-font
      liberation_ttf
      mplus-outline-fonts.githubRelease
      nerd-fonts.hack
      nerd-fonts.iosevka
      nerd-fonts.symbols-only
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      # proggyfonts
    ]);

    username = "thomaj81";
    homeDirectory = "/home/thomaj81";

    stateVersion = "25.11";
  };
}
