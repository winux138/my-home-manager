{
  inputs,
  # lib,
  config,
  pkgs,
  unstable,
  nixgl,
  ...
}:
let
  wrap = config.lib.nixGL.wrap;
in
{
  imports = [
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
  programs.fish.enable = true;
  programs.fish.interactiveShellInit = ''
    if command -q nix-your-shell
      nix-your-shell fish | source
    end
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

  programs.opencode = {
    enable = true;
    package = unstable.opencode;

    settings.instructions = [
      "/home/thomaj81/Notes/ai/memory/rust.md"
      "/home/thomaj81/Notes/ai/memory/git.md"
    ];

    context = builtins.readFile ./pi/skills/kem-reply/SKILL.md + ''

      ## Long-term memory
      Memory: /home/thomaj81/Notes/ai/memory/rust.md and /home/thomaj81/Notes/ai/memory/git.md (loaded via instructions).
      When the user corrects you (preference, naming, tooling, repeated mistake), append a one-line dated bullet to the matching file. Check first - never record the same correction twice. If neither fits, create a new file in that memory dir.
    '';
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
    ]);

    username = "thomaj81";
    homeDirectory = "/home/thomaj81";

    stateVersion = "25.11";
  };
}
