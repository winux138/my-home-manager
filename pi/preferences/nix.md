# Nix Preferences

## Flakes

- Use a flake for project dependencies and packages.
- Put required tools/dependencies into the flake instead of assuming system packages.
- Add dependencies just in time; do not overpopulate the dev shell early.

## Packages and apps

- Expose runnable packages and apps when the project becomes executable:

```text
packages.default
apps.default
```

- If a binary needs runtime tools on `PATH`, wrap it explicitly in the package.

## Home Manager

- Home Manager modules are useful when the tool is a user-facing long-running service.
- Prefer options with explicit types and documented defaults.
- If systemd user services depend on graphical session variables, document this clearly.

## Build resource usage

- Leave at least 2 CPU cores unused when more than 2 exist; otherwise use 1 core.
- Prefer:

```bash
cores=$(nproc); nix build . --max-jobs 1 --cores $(( cores > 2 ? cores - 2 : 1 ))
```

- `--cores` alone is not enough to cap total system CPU use.

## Source filtering

- Use source filtering for Nix builds when repository contains build outputs or large/generated files.
- Ensure the filtered source still includes all workspace members and required assets.

## Generated assets

- Committed generated assets are acceptable when explicitly chosen for simplicity.
- Add a drift test if a generator produces a committed artifact.
- Do not install generator/debug binaries in runtime package unless intended.
