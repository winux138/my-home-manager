{ lib, pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      hello
      vim
    ];

    username = "ju";
    homeDirectory = "/home/ju";

    stateVersion = "25.11";
  };
}
