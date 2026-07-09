{ lib, pkgs, ... }:
{
  programs.helix = {
    enable = true;
    defaultEditor = true;
    extraPackages = with pkgs; [
      kdePackages.qtdeclarative
      rust-analyzer
      crates-lsp
      nil
    ];
  };
}
