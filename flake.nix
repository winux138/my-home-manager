{
  description = "My home manager config";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      firefox-addons,
      ...
    }@inputs:
    let
      # lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
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
          extraSpecialArgs = { inherit inputs home-manager; };
          inherit pkgs;
          modules = [
            inputs.nvf.homeManagerModules.default
            ./home-office.nix
          ];
        };
      };
    };
}
