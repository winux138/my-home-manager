{
  description = "My home manager config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      nvf,
      firefox-addons,
      nixgl,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      unstable = import nixpkgs-unstable { inherit system; };

      # Standalone neovim, reusing the exact settings from neovim.nix.
      neovim =
        (nvf.lib.neovimConfiguration {
          inherit pkgs;
          modules = [ { config.vim = (import ./neovim.nix { inherit pkgs; }).programs.nvf.settings.vim; } ];
        }).neovim;
    in
    {
      # Binaries exposed by this flake. Run any of them with:
      #   nix run github:<owner>/<repo>#<name>
      # Add more by dropping another entry in packages/apps below.
      packages.${system} = {
        neovim = neovim;
      };

      apps.${system} = {
        neovim = {
          type = "app";
          program = "${neovim}/bin/nvim";
        };
      };

      homeConfigurations = {
        ubuntu-home = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = { inherit inputs; };
          inherit pkgs;
          modules = [
            inputs.nvf.homeManagerModules.default
            ./home.nix
          ];
        };
        ubuntu-office = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = { inherit inputs home-manager unstable nixgl; };
          inherit pkgs;
          modules = [
            inputs.nvf.homeManagerModules.default
            ./home-office.nix
          ];
        };
      };
    };
}
