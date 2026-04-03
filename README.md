# Dotfiles

Hybrid dotfiles repo:

- native files in `home/` are the source of truth
- `mksymlinks.sh` supports non-Nix systems
- Home Manager supports `out-of-store` and `store` deployments

## Layout

- `symlinks.txt`: explicit user-facing links (`home` and `xdg-config` roots)
- `runtime-files.txt`: repo files that must exist under `$TERMENV`
- `modules/symlinked-home-files.nix`: shared manifest engine for `symlinks.txt`
- `dotfiles.nix`: dotfiles policy module
- `common.nix`: general HM config, separate from dotfiles linking

## TERMENV

- `~/.profile` sources optional `~/.profile.local` first
- if `TERMENV` is still unset, it defaults to `$HOME/terminalenv`
- Bash and Neovim expect runtime files under `$TERMENV`, e.g. `$TERMENV/home/bash/...`

## Deployment Modes

Native / non-Nix:

- keep a checkout at `~/terminalenv`
- run `mksymlinks.sh`

Home Manager `out-of-store`:

- symlink entrypoints back to the checkout
- requires a local checkout at `~/terminalenv` by default
- if no checkout exists, activation fails with a clear error

Home Manager `store`:

- materialize entrypoints from the flake source
- create only the files listed in `runtime-files.txt` under `~/terminalenv`
- works for flake-only consumers with no local checkout

## External Consumers

Recommended split:

- import `dotfiles.modules.dotfiles` for linking/runtime behavior
- import `dotfiles.modules.common` for the shared HM config

`store` mode works without a checkout.

`out-of-store` mode needs a checkout unless you explicitly override both:

- `TERMENV`
- `dotfiles.links.repoRoot`

## Tests

- full integration: `bash tests/test-deployments.sh`
- refresh cached test image: `bash tests/refresh-test-image.sh`
- flake check: `nix build "path:$PWD#checks.x86_64-linux.deployment-tests"`

The tests cover:

- native deployment
- HM out-of-store and store
- external flake consumer in store mode
- external flake consumer failure in out-of-store mode without a checkout
