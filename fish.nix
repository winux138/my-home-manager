{ pkgs, ... }:
{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      if command -q nix-your-shell
        nix-your-shell fish | source
      end
    '';
  };

  home.packages = [ pkgs.nix-your-shell ];
}
