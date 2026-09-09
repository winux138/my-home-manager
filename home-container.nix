{ pkgs, ... }:
{
  imports = [
    ./fish.nix
    ./git.nix
    ./helix.nix
    ./neovim.nix
    ./pi.nix
    ./tmux.nix
  ];

  programs.home-manager.enable = true;

  # Debian container, not NixOS: sets up locale archive, XDG_DATA_DIRS and /etc profile hooks.
  targets.genericLinux.enable = true;

  programs.bash = {
    enable = true;
    initExtra = ''
      eval "$(direnv hook bash)"

      # Land in fish for interactive shells. Home Manager cannot chsh in this container, and
      # /etc/passwd is baked into the image. The -x guard means a broken fish leaves bash usable.
      if [[ $- == *i* && -z ''${IN_NIX_SHELL-} && -z ''${FISH_LAUNCHED-} && -x "$HOME/.nix-profile/bin/fish" ]]; then
        FISH_LAUNCHED=1 exec "$HOME/.nix-profile/bin/fish"
      fi
    '';
  };

  home = {
    packages = with pkgs; [
      bat
      bottom
      curl
      direnv
      dust
      eza
      fastfetch
      fd
      fzf
      gh
      htop
      ouch
      ripgrep
      rsync
      tmux
      tree
    ];

    username = "root";
    homeDirectory = "/root";

    stateVersion = "25.11";
  };
}
