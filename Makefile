.PHONY: update
update:
	home-manager switch --flake .#ubuntu-home

.PHONY: clean
clean:
	nix-collect-garbage --delete-generations 15d
