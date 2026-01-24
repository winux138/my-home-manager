{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.emacs-overlay.overlays.default ];

  services.emacs.enable = true;

  programs.emacs = {
    enable = true;
    package = (
      pkgs.emacsWithPackagesFromUsePackage {
        config = ./config/emacs/emacs.el;
        defaultInitFile = true;
        alwaysEnsure = true;
        # package = pkgs.emacs.override {
        #   withTreeSitter = true;
        #   withNativeCompilation = true;
        # };
      }
    );
  };
}
