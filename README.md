# Dotfiles

Dotfiles repo with one canonical `home/` tree:

- native deployment uses `stow`
- Home Manager supports `out-of-store` and `store` deployments

## Layout

- `home/`: files laid out exactly as they should appear under `$HOME`
- `mksymlinks.sh`: native Stow wrapper
- `dotfiles.nix`: Home Manager deployment policy
- `common.nix`: general Home Manager config

## Deployment Modes

Native / non-Nix:

- keep a checkout at `~/terminalenv`
- run `mksymlinks.sh`

Home Manager `out-of-store`:

- restow `home/` from the checkout during activation
- requires a local checkout at `~/terminalenv` by default
- if no checkout exists, activation fails with a clear error

Home Manager `store`:

- materialize files from `home/` into the Nix store
- works for flake-only consumers with no local checkout

## External Consumers

Recommended split:

- import `dotfiles.modules.dotfiles` for linking/runtime behavior
- import `dotfiles.modules.common` for the shared HM config

`store` mode works without a checkout.

`out-of-store` mode needs a checkout unless you override:

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
