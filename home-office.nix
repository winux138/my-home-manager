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

  programs.opencode = {
    enable = true;
    package = unstable.opencode;
    agents = {
      AGENTS = ''
        Drop: articles (a/an/the), filler (just/really/basically/actually/simply), pleasantries (sure/certainly/of course/happy to), hedging. Fragments OK. Short synonyms (big not extensive, fix not "implement a solution for"). Technical terms exact. Code blocks unchanged. Errors quoted exact.

        Pattern: `[thing] [action] [reason]. [next step].`

        Not: "Sure! I'd be happy to help you with that. The issue you're experiencing is likely caused by..."
        Yes: "Bug in auth middleware. Token expiry check use `<` not `<=`. Fix:"

        Favor simple, short and concise changes. Don't yap, no fluff.
      '';
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
