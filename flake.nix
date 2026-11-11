{
  description = "My home manager config";

  nixConfig = {
    extra-substituters = [ "https://hyprland.cachix.org" ];
    extra-trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    hyprland.url = "github:hyprwm/Hyprland/5a78b5e927345860a27e2893bf894f97ee620c48";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins/428bfcd1c9ee34965400bb359349f518140c9920";
      inputs.hyprland.follows = "hyprland";
    };
    monique = {
      url = "git+https://github.com/ToRvaLDz/monique?rev=d656eea5cbd4d79577442c818f66fce8876714c7";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

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

      piPackage = unstable.pi-coding-agent;

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
        # For hosts without ubuntu-office Home Manager: `nix profile install .#pi`.
        # ubuntu-office already installs this same package.
        pi = piPackage;
        # Home Manager from this flake's locked input. Hosts without it installed can
        # `nix run .#home-manager -- switch --flake .#<config>`; resolving
        # `home-manager/release-26.05` instead goes through api.github.com, which
        # rate-limits anonymous requests from shared-egress containers.
        home-manager = home-manager.packages.${system}.home-manager;
      };

      apps.${system} = {
        neovim = {
          type = "app";
          program = "${neovim}/bin/nvim";
        };
        pi = {
          type = "app";
          program = nixpkgs.lib.getExe piPackage;
        };
      };

      homeConfigurations = {
        ubuntu-home = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = { inherit inputs unstable; };
          inherit pkgs;
          modules = [
            inputs.nvf.homeManagerModules.default
            ./home.nix
          ];
        };
        ubuntu-office = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = { inherit inputs home-manager unstable nixgl piPackage; };
          inherit pkgs;
          modules = [
            inputs.nvf.homeManagerModules.default
            ./home-office.nix
          ];
        };
        # Headless container / devcontainer: terminal tooling only, runs as root.
        ona = home-manager.lib.homeManagerConfiguration {
          extraSpecialArgs = { inherit inputs unstable piPackage; };
          inherit pkgs;
          modules = [
            inputs.nvf.homeManagerModules.default
            ./home-container.nix
          ];
        };
      };
    };
}
