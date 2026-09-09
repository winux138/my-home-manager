.PHONY: update
update:
	home-manager switch --flake .#ubuntu-home

# Headless container: home-manager is not installed there, so run it from the flake.
.PHONY: ona
ona:
	nix run .#home-manager -- switch -b backup --flake .#ona

.PHONY: clean
clean:
	nix-collect-garbage --delete-generations 15d
