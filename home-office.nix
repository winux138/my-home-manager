{
  inputs,
  # lib,
  pkgs,
  unstable,
  ...
}:
# let
# in
{
  imports = [
    ./git.nix
    ./tmux.nix
    ./polybar.nix
  ];

  programs.home-manager.enable = true;
  nixpkgs.config.allowUnfree = true;

  programs.bash.enable = true;
  programs.bash.initExtra = ''
    eval "$(direnv hook bash)"
  '';
  programs.fish.enable = true;
  programs.fish.interactiveShellInit = ''
    if command -q nix-your-shell
      nix-your-shell fish | source
    end
  '';

  fonts.fontconfig.enable = true;

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
    profiles.thomaj81.extensions.packages = with inputs.firefox-addons.packages.${pkgs.system}; [
      ublock-origin
      consent-o-matic
      tridactyl
    ];
  };

  programs.gh = {
    enable = true;
    extensions = with pkgs; [
      gh-f
      gh-i
      gh-s
      gh-cal
      gh-dash
      gh-notify
      gh-copilot
      gh-skyline

      (pkgs.buildGoModule {
        pname = "gh-pr-review";
        version = "1.6.2";
        src = pkgs.fetchFromGitHub {
          owner = "agynio";
          repo = "gh-pr-review";
          rev = "v1.6.2";
          hash = "sha256-1TINm9rMckjAG7nyBR5AqSqWpzVp6ey7c1wm98s488w=";
        };
        vendorHash = "sha256-CEV23koYz0FpSWXJRF4J+dGNuDT8Ftkn4LGFftvd0ts=";
      })
    ];

    settings = {
      git_protocol = "ssh";
    };
  };

  home = {
    packages = with pkgs; [
      # proprietary / work related
      # vscode

      meld
      plantuml
      pandoc
      krita
      kitty
      keepassxc
      # quickshell
      polybar
      brightnessctl
      flameshot
      dust

      xclip
      arandr
      lazygit
      helix
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
      unstable.opencode
      curl

      direnv
      nix-your-shell

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
    ];

    username = "thomaj81";
    homeDirectory = "/home/thomaj81";

    stateVersion = "25.11";
  };
}
