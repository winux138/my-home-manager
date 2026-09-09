{ pkgs, ... }:
{
  home.packages = [ pkgs.azure-cli ];
  home.shellAliases.ls = "eza";

  programs.gh = {
    enable = true;
    extensions = [ pkgs.gh-stack ];
    gitCredentialHelper.enable = false;
  };
}
