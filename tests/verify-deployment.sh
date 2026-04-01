#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT=/repo
MANIFEST="$REPO_ROOT/symlinks.txt"
TEST_ROOT="${TEST_ROOT:-/tmp/terminalenv-tests}"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

log() {
  printf '==> %s\n' "$*"
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

setup_home() {
  local name="$1"

  export HOME="$TEST_ROOT/$name/home"
  export USER=tester
  export LOGNAME=tester
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_CACHE_HOME="$HOME/.cache"
  export XDG_DATA_HOME="$HOME/.local/share"
  export XDG_STATE_HOME="$HOME/.local/state"
  export TERM=xterm-256color

  rm -rf "$HOME"
  mkdir -p "$HOME" "$XDG_STATE_HOME/nix/profiles" "$XDG_STATE_HOME/home-manager/gcroots"
}

assert_core_files_exist() {
  [[ -f "$HOME/.bashrc" ]] || fail "Missing ~/.bashrc"
  [[ -f "$HOME/.profile" ]] || fail "Missing ~/.profile"
  [[ -f "$HOME/.inputrc" ]] || fail "Missing ~/.inputrc"
  [[ -f "$HOME/.tmux.conf" ]] || fail "Missing ~/.tmux.conf"
  [[ -f "$HOME/.latexmkrc" ]] || fail "Missing ~/.latexmkrc"
  [[ -x "$HOME/.local/bin/update-packages" ]] || fail "update-packages is not executable"
  [[ -f "$XDG_CONFIG_HOME/home-manager/flake.nix" ]] || fail "Missing Home Manager flake link"
  [[ -d "$XDG_CONFIG_HOME/terminalenv/bash" ]] || fail "Missing terminalenv bash support directory"
  [[ -f "$XDG_CONFIG_HOME/terminalenv/bash/lib.sh" ]] || fail "Missing bash support file lib.sh"
  [[ -f "$XDG_CONFIG_HOME/terminalenv/bash/completions/git" ]] || fail "Missing vendored git completion script"
  [[ -d "$XDG_CONFIG_HOME/terminalenv/nvim" ]] || fail "Missing terminalenv nvim support directory"
  [[ -f "$XDG_CONFIG_HOME/terminalenv/nvim/settings.vim" ]] || fail "Missing nvim settings file"
  [[ -d "$XDG_CONFIG_HOME/git/template" ]] || fail "Missing git template directory"
}

assert_links() {
  local expected_kind="$1"
  local path
  local resolved

  while IFS='|' read -r root source target; do
    if [[ -z "$root" || "$root" == \#* ]]; then
      continue
    fi

    case "$root" in
      home)
        path="$HOME/$target"
        ;;
      xdg-config)
        path="$XDG_CONFIG_HOME/$target"
        ;;
      *)
        fail "Unknown manifest root: $root"
        ;;
    esac

    [[ -L "$path" ]] || fail "$path is not a symlink"
    resolved="$(readlink -f "$path")"

    case "$expected_kind" in
      repo)
        [[ "$resolved" == "/repo/$source" ]] || fail "$path resolved to $resolved, expected /repo/$source"
        ;;
      store)
        [[ "$resolved" == /nix/store/* ]] || fail "$path resolved to $resolved, expected /nix/store/*"
        ;;
      *)
        fail "Unknown expected link kind: $expected_kind"
        ;;
    esac
  done < "$MANIFEST"
}

assert_bash_works() {
  bash -i -c 'complete -p ga >/dev/null && [ "$TERMENV" = "$XDG_CONFIG_HOME/terminalenv" ]'
}

assert_profile_works() {
  bash -lc '[ "$TERMENV" = "$XDG_CONFIG_HOME/terminalenv" ] && [ -f "$TERMENV/bash/lib.sh" ]'
}

assert_link_roots() {
  [[ -L "$XDG_CONFIG_HOME/terminalenv/bash" ]] || fail "terminalenv bash support path is not a symlink"
  [[ -L "$XDG_CONFIG_HOME/terminalenv/nvim" ]] || fail "terminalenv nvim support path is not a symlink"
}

assert_home_manager_profile_state() {
  [[ -L "$XDG_STATE_HOME/nix/profiles/home-manager" ]] || fail "Home Manager profile symlink was not created in XDG state"
}

assert_git_config_template_dir() {
  [[ "$(git config --global init.templateDir)" == "$XDG_CONFIG_HOME/git/template" ]] || fail "git init.templateDir was not configured correctly"
}

assert_idempotent_script() {
  TERMENV=/repo bash /repo/mksymlinks.sh >/dev/null
}

assert_idempotent_activation() {
  local activation="$1"

  "$activation/activate" >/dev/null
}

build_activation() {
  local mode="$1"

  nix --extra-experimental-features 'nix-command flakes' build \
    --impure \
    --no-link \
    --print-out-paths \
    --file /repo/tests/home-manager-activation.nix \
    --argstr mode "$mode" \
    --argstr homeDirectory "$HOME"
}

build_external_consumer_activation() {
  local consumer_root="$TEST_ROOT/external-consumer"

  rm -rf "$consumer_root"
  mkdir -p "$consumer_root"
  ln -sfn /repo "$HOME/terminalenv"

  cat > "$consumer_root/flake.nix" <<EOF
{
  inputs = {
    dotfiles.url = "path:/repo";
    nixpkgs.follows = "dotfiles/nixpkgs";
    home-manager.follows = "dotfiles/home-manager";
  };

  outputs = { nixpkgs, home-manager, dotfiles, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.\${system};
    in {
      homeConfigurations.tester = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          dotfiles.modules.common
          {
            home.username = "tester";
            home.homeDirectory = "${HOME}";
            home.stateVersion = "24.11";
          }
        ];
      };
    };
}
EOF

  nix --extra-experimental-features 'nix-command flakes' build \
    --no-link \
    --print-out-paths \
    "$consumer_root#homeConfigurations.tester.activationPackage"
}

run_script_mode() {
  setup_home script
  log "Testing native symlink deployment"
  TERMENV=/repo bash /repo/mksymlinks.sh
  assert_idempotent_script
  assert_links repo
  assert_link_roots
  assert_core_files_exist
  assert_profile_works
  assert_bash_works
  [[ ! -e "$XDG_STATE_HOME/nix/profiles/home-manager" ]] || fail "Script mode unexpectedly created a Home Manager profile"
}

run_home_manager_mode() {
  local mode="$1"
  local expected_kind="$2"
  local activation

  setup_home "home-manager-$mode"
  log "Testing Home Manager deployment ($mode via flake module output)"
  activation="$(build_activation "$mode")"
  "$activation/activate"
  assert_idempotent_activation "$activation"
  assert_links "$expected_kind"
  assert_link_roots
  assert_core_files_exist
  assert_profile_works
  assert_bash_works
  assert_home_manager_profile_state
  assert_git_config_template_dir
}

run_external_flake_module_mode() {
  local activation

  setup_home external-flake
  log "Testing external flake path-ref consumer via dotfiles.modules.common"
  activation="$(build_external_consumer_activation)"
  "$activation/activate"
  assert_idempotent_activation "$activation"
  assert_links repo
  assert_link_roots
  assert_core_files_exist
  assert_profile_works
  assert_bash_works
  assert_home_manager_profile_state
  assert_git_config_template_dir
}

run_script_mode
run_home_manager_mode out-of-store repo
run_home_manager_mode store store
run_external_flake_module_mode

log "All deployment models passed"
