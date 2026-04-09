#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT=/repo
TEST_ROOT="${TEST_ROOT:-/tmp/terminalenv-tests}"
DOTFILES_FLAKE_ROOT="$TEST_ROOT/dotfiles-flake"
STOW_BIN_DIR=""

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

package_tree_entries() {
  local package
  local relative_path

  for package in "$@"; do
    (
      cd "$REPO_ROOT/$package"
      find . -type f -printf '%P\n' | sort
    ) | while IFS= read -r relative_path; do
      printf '%s\t%s\n' "$package" "$relative_path"
    done
  done
}

ensure_stow() {
  if [[ -n "$STOW_BIN_DIR" ]]; then
    return
  fi

  local stow_path
  stow_path="$(nix --extra-experimental-features 'nix-command flakes' build --impure --no-link --print-out-paths --expr 'let flake = builtins.getFlake ("path:" + toString /repo); in flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem}.stow')"
  STOW_BIN_DIR="$stow_path/bin"
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

prepare_flake_snapshot() {
  if [[ -d "$DOTFILES_FLAKE_ROOT" ]]; then
    return
  fi

  mkdir -p "$DOTFILES_FLAKE_ROOT"
  cp -a /repo/. "$DOTFILES_FLAKE_ROOT"
  rm -rf "$DOTFILES_FLAKE_ROOT/.git"
  rm -rf "$DOTFILES_FLAKE_ROOT/result"
}

seed_checkout() {
  mkdir -p "$HOME/terminalenv"
  cp -a /repo/. "$HOME/terminalenv"
  chmod -R u+w "$HOME/terminalenv" 2>/dev/null || true
  rm -rf "$HOME/terminalenv/result"
}

assert_core_files_exist() {
  [[ -f "$HOME/.bashrc" ]] || fail "Missing ~/.bashrc"
  [[ -f "$HOME/.profile" ]] || fail "Missing ~/.profile"
  [[ -f "$HOME/.inputrc" ]] || fail "Missing ~/.inputrc"
  [[ -f "$HOME/.tmux.conf" ]] || fail "Missing ~/.tmux.conf"
  [[ -x "$HOME/.local/bin/update-packages" ]] || fail "update-packages is not executable"
  [[ -f "$XDG_CONFIG_HOME/latexmk/latexmkrc" ]] || fail "Missing ~/.config/latexmk/latexmkrc"
  [[ -f "$XDG_CONFIG_HOME/nvim/init.vim" ]] || fail "Missing ~/.config/nvim/init.vim"
  [[ ! -e "$XDG_CONFIG_HOME/nvim/init.lua" ]] || fail "Unexpected ~/.config/nvim/init.lua"
  [[ -d "$XDG_CONFIG_HOME/repos/template/dot-git" ]] || fail "Missing repos template dot-git directory"
  [[ -f "$XDG_CONFIG_HOME/repos/template/dot-gitignore" ]] || fail "Missing repos template dot-gitignore file"
}

assert_links() {
  local expected_kind="$1"
  shift

  local package
  local path
  local resolved
  local relative_path

  while IFS=$'\t' read -r package relative_path; do
    path="$HOME/$relative_path"

    [[ -e "$path" ]] || { ls -lah "$(dirname "$path")" ; fail "$path does not exist" ; }
    resolved="$(readlink -f "$path")"

    case "$expected_kind" in
      runtime)
        [[ "$resolved" == "$HOME/terminalenv/$package/$relative_path" ]] || fail "$path resolved to $resolved, expected $HOME/terminalenv/$package/$relative_path"
        ;;
      store)
        [[ "$resolved" == /nix/store/* ]] || fail "$path resolved to $resolved, expected /nix/store/*"
        ;;
      *)
        fail "Unknown expected link kind: $expected_kind"
        ;;
    esac
  done < <(package_tree_entries "$@")
}

assert_bash_works() {
  bash -i -c 'complete -p ga >/dev/null && [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/bash/lib.sh" ]'
}

assert_profile_works() {
  bash -lc 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) exit 1 ;; esac'
}

assert_neovim_home_manager_files() {
  [[ -f "$XDG_CONFIG_HOME/nvim/hm-generated.lua" ]] || fail "Missing ~/.config/nvim/hm-generated.lua"
  [[ ! -e "$XDG_CONFIG_HOME/nvim/init.lua" ]] || fail "Unexpected ~/.config/nvim/init.lua"
}

assert_no_dangling_symlinks() {
  local dangling

  dangling="$({ find "$HOME" -xtype l 2>/dev/null || true; find "$XDG_CONFIG_HOME" -xtype l 2>/dev/null || true; } | sort -u)"

  if [[ -n "$dangling" ]]; then
    fail "Found dangling symlinks:${dangling}"
  fi
}

assert_home_manager_profile_state() {
  [[ -L "$XDG_STATE_HOME/nix/profiles/home-manager" ]] || fail "Home Manager profile symlink was not created in XDG state"
}

assert_git_config_local_override() {
  [[ "$(git config --global include.path)" == "~/.config/git/config.local" ]] || fail "git include.path was not configured correctly"
}

assert_git_diff_external() {
  [[ "$(git config --global diff.external)" == "difft" ]] || fail "git diff.external was not configured correctly"
}

assert_git_init_uses_repos() {
  local repo_path="$TEST_ROOT/templated-repo"
  local gitignore_path="$repo_path/.gitignore"
  local home_manager_path

  rm -rf "$repo_path"
  home_manager_path="$(readlink -f "$XDG_STATE_HOME/nix/profiles/home-manager/home-path")"
  PATH="$home_manager_path/bin:$PATH" repos init "$repo_path" >/dev/null

  [[ -f "$gitignore_path" ]] || fail "git init did not apply the repos template"
}

assert_idempotent_script() {
  PATH="$STOW_BIN_DIR:$PATH" bash "$HOME/terminalenv/mksymlinks.sh" >/dev/null
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
    --argstr flakeRoot "$DOTFILES_FLAKE_ROOT" \
    --argstr mode "$mode" \
    --argstr homeDirectory "$HOME" \
    --argstr repoRoot "$HOME/terminalenv"
}

build_external_consumer_activation() {
  local mode="$1"
  local consumer_root="$TEST_ROOT/external-consumer"
  local overrides

  rm -rf "$consumer_root"
  mkdir -p "$consumer_root"

  case "$mode" in
    out-of-store)
      overrides='dotfiles.links.mode = lib.mkForce "out-of-store";'
      ;;
    store)
      overrides='dotfiles.links.mode = lib.mkForce "store";'
      ;;
    *)
      fail "Unknown external consumer mode: $mode"
      ;;
  esac

  cat > "$consumer_root/flake.nix" <<EOF
{
  inputs = {
    dotfiles.url = "path:${DOTFILES_FLAKE_ROOT}";
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
          dotfiles.modules.dotfiles
          dotfiles.modules.common
          dotfiles.modules.nixpkgs-registry
          ({ lib, ... }: {
            home.username = "tester";
            home.homeDirectory = "${HOME}";
            home.stateVersion = "24.11";
            ${overrides}
          })
        ];
        extraSpecialArgs = {
          nixpkgsFlake = nixpkgs;
          ownPkgs = dotfiles.packages.\${system};
        };
      };
    };
}
EOF

  nix --extra-experimental-features 'nix-command flakes' flake lock \
    "$consumer_root" >/dev/null 2>&1

  nix --extra-experimental-features 'nix-command flakes' build \
    --no-link \
    --print-out-paths \
    "$consumer_root#homeConfigurations.tester.activationPackage"
}

assert_out_of_store_activation_failure() {
  local activation="$1"
  local output

  output="$({ "$activation/activate"; } 2>&1 || true)"
  case "$output" in
    *"Out-of-store dotfiles mode requires a local checkout at $HOME/terminalenv."*)
      ;;
    *)
      fail "Missing expected out-of-store activation failure message. Output was: $output"
      ;;
  esac
}

run_script_mode() {
  setup_home script
  seed_checkout
  ensure_stow
  log "Testing native symlink deployment"
  PATH="$STOW_BIN_DIR:$PATH" bash "$HOME/terminalenv/mksymlinks.sh" repos
  assert_idempotent_script
  assert_links runtime home opencode
  assert_no_dangling_symlinks
  assert_core_files_exist
  assert_profile_works
  assert_git_config_local_override
  assert_git_diff_external
  assert_bash_works
  [[ ! -e "$XDG_STATE_HOME/nix/profiles/home-manager" ]] || fail "Script mode unexpectedly created a Home Manager profile"
}

run_home_manager_mode() {
  local mode="$1"
  local expected_kind="$2"
  local activation

  setup_home "home-manager-$mode"
  prepare_flake_snapshot
  if [[ "$mode" == "out-of-store" ]]; then
    seed_checkout
  fi
  log "Testing Home Manager deployment ($mode via flake module output)"
  activation="$(build_activation "$mode")"
  "$activation/activate"
  assert_idempotent_activation "$activation"
  assert_links "$expected_kind" home repos opencode
  assert_no_dangling_symlinks
  assert_core_files_exist
  assert_neovim_home_manager_files
  assert_profile_works
  assert_bash_works
  assert_home_manager_profile_state
  assert_git_config_local_override
  assert_git_diff_external
  assert_git_init_uses_repos
}

run_external_flake_module_mode() {
  local mode="$1"
  local expected_kind="$2"
  local activation

  setup_home "external-flake-$mode"
  prepare_flake_snapshot
  if [[ "$mode" == "out-of-store" ]]; then
    log "Testing external flake path-ref consumer via dotfiles.modules.{dotfiles,common} ($mode, no local checkout)"
    activation="$(build_external_consumer_activation "$mode")"
    assert_out_of_store_activation_failure "$activation"
    return
  fi

  log "Testing external flake path-ref consumer via dotfiles.modules.common ($mode)"
  activation="$(build_external_consumer_activation "$mode")"
  "$activation/activate"
  assert_idempotent_activation "$activation"
  assert_links store home repos opencode
  assert_no_dangling_symlinks
  assert_core_files_exist
  assert_neovim_home_manager_files
  assert_profile_works
  assert_bash_works
  assert_home_manager_profile_state
  assert_git_config_local_override
  assert_git_diff_external
  assert_git_init_uses_repos
}

run_script_mode
run_home_manager_mode out-of-store runtime
run_home_manager_mode store store
run_external_flake_module_mode out-of-store runtime
run_external_flake_module_mode store store

log "All deployment models passed"
