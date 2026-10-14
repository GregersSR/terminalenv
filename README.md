# Dotfiles

Dotfiles repo with Stow packages under `dotpkgs/`:

- native deployment uses `stow`
- Home Manager supports `out-of-store` and `store` deployments

## Layout

- `dotpkgs/home/`: primary files laid out exactly as they should appear under `$HOME`
- `dotpkgs/aitools/`: AI tool config layered into `$HOME`
- `dotpkgs/repos/`: repo tooling layered into `$HOME`
- `mksymlinks.sh`: native Stow wrapper
- `dotfiles.nix`: Home Manager deployment policy
- `common.nix`: general Home Manager config

## Deployment Modes

Native / non-Nix:

- keep a checkout at `~/terminalenv`
- install GNU Stow
- run `bash ~/terminalenv/mksymlinks.sh` to restow every package under `dotpkgs/`

Home Manager `out-of-store`:

- restow the configured `dotpkgs/` packages from the checkout during activation
- requires a local checkout at `~/terminalenv` by default
- if no checkout exists, activation fails with a clear error

Home Manager `store`:

- materialize files from the configured `dotpkgs/` packages into the Nix store
- works for flake-only consumers with no local checkout

## External Consumers

Recommended split:

- import `dotfiles.modules.dotfiles` for linking/runtime behavior
- import `dotfiles.modules.common` for the shared HM config

`store` mode works without a checkout.

`out-of-store` mode uses string filesystem paths in `dotfiles.packages`; those
directories must exist at activation time.

## Tests

- full integration: `bash tests/test-deployments.sh`
- refresh cached test image: `bash tests/refresh-test-image.sh`
- flake check: `nix build "path:$PWD#checks.x86_64-linux.deployment-tests"`

The tests cover:

- native deployment
- HM out-of-store and store
- external flake consumer in store mode
- external flake consumer failure in out-of-store mode without a checkout
