# Dotfiles

This repository uses a hybrid approach:

- Native config files in `home/` are the source of truth.
- Nix and Home Manager are used when available for packages, integrations, and higher-level defaults.
- The setup should remain usable on systems where Nix is not available.

## Goal

The main goal is to keep a workable terminal environment on any system while still benefiting from Home Manager where it helps.

That means:

- Plain config files should live in the repo in a normal, portable form.
- Those files should be symlinked into their final locations.
- The symlink definitions should be shared between the non-Nix and Nix-based setup paths.

## Intended Linking Model

The repo now has one shared symlink manifest in `symlinks.txt`.

That manifest will be consumed by:

1. `mksymlinks.sh`
   For machines without Nix. It creates the necessary symlinks directly.
2. `modules/symlinked-home-files.nix`
   For machines with Nix. It uses the same definitions and supports two modes:
   - out-of-store symlinks
   - normal `home.file` / `xdg.configFile` entries

Each line in `symlinks.txt` has the form `root|source|target`.

- `root` is either `home` or `xdg-config`
- `source` is a repo-relative path
- `target` is relative to the selected root

The important part is that the path definitions are shared, so there is only one place to maintain them.

## Current Direction

The preferred direction is to let the native config files own their final paths directly.

In practice, that now means preferring:

- `~/.bashrc` pointing to the repo's Bash config
- `~/.profile` pointing to the repo's profile
- other plain files such as tmux, inputrc, starship, and similar files also pointing directly to repo files

Home Manager can either:

- materialize those files from the flake source in the store
- or create out-of-store symlinks back to the checkout

The current Home Manager configuration uses out-of-store links for the shared manifest so the checkout stays authoritative.

The shared files are also exposed under `$XDG_CONFIG_HOME/terminalenv`, which gives Bash and Neovim a stable runtime location even when Home Manager uses store-backed files.

This keeps control in the repo instead of in Home Manager-generated wrapper files.

## Why Prefer Native Ownership

This approach keeps the behavior closer between:

- systems with Home Manager
- systems without Home Manager

It also makes the repo easier to reason about:

- the file in the repo is the real config
- the final path is just a symlink to it
- Home Manager can help without becoming the owner of the file content

## Role of Home Manager

Home Manager should still be used where it adds value, for example:

- installing packages
- enabling programs and integrations
- setting Git options and other structured settings
- managing shell-related support that does not need to own the user-facing config file

The goal is for Home Manager to stay out of the way when the native file should be authoritative.

## Notes on Specific Tools

### Zsh

Zsh looks promising for this model because Home Manager supports putting Zsh config in alternate locations. That may make it possible to keep native files authoritative while still using Home Manager features.

### Neovim

Neovim is less straightforward. It is easier for Home Manager to layer behavior around Neovim than it is to fully get out of the way. This likely needs a separate decision:

- either keep Neovim mostly native
- or allow some Home Manager ownership or wrapper-based integration there

## Summary

The current architectural preference is:

- native config files remain the primary source of truth
- symlink definitions are shared across Nix and non-Nix setup paths
- Home Manager is used as a helper layer, not the default owner of config file contents

Where Home Manager can cleanly stay out of the way, it should.

## Current Status

The shared manifest currently covers:

- Bash and profile entry points
- Bash support files under `$XDG_CONFIG_HOME/terminalenv/bash`
- inputrc and tmux
- Neovim support files under `$XDG_CONFIG_HOME/terminalenv/nvim`
- starship
- latexmk
- Git template files
- the Home Manager flake entry point
- the `update-packages` helper script

Neovim is still handled separately through Home Manager configuration that sources the repo file, since that is less straightforward to move over cleanly.
