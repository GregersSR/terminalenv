#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT=/repo
MANIFEST="$REPO_ROOT/symlinks.txt"
RUNTIME_FILES_MANIFEST="$REPO_ROOT/runtime-files.txt"
TEST_ROOT="${TEST_ROOT:-/tmp/terminalenv-tests}"
DOTFILES_FLAKE_ROOT="$TEST_ROOT/dotfiles-flake"

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
  unset TERMENV

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
  rm -rf "$HOME/terminalenv/result"
}

assert_core_files_exist() {
  [[ -f "$HOME/.bashrc" ]] || fail "Missing ~/.bashrc"
  [[ -f "$HOME/.profile" ]] || fail "Missing ~/.profile"
  [[ -f "$HOME/.inputrc" ]] || fail "Missing ~/.inputrc"
  [[ -f "$HOME/.tmux.conf" ]] || fail "Missing ~/.tmux.conf"
  [[ -f "$HOME/.latexmkrc" ]] || fail "Missing ~/.latexmkrc"
  [[ -x "$HOME/.local/bin/update-packages" ]] || fail "update-packages is not executable"
  [[ -e "$HOME/terminalenv" ]] || fail "Missing ~/terminalenv runtime root"
  [[ -f "$HOME/terminalenv/home/bash/lib.sh" ]] || fail "Missing runtime bash support file"
  [[ -f "$HOME/terminalenv/home/bash/completions/git" ]] || fail "Missing runtime vendored git completion script"
  [[ -f "$HOME/terminalenv/home/nvim/settings.vim" ]] || fail "Missing runtime nvim settings file"
  [[ -f "$XDG_CONFIG_HOME/home-manager/flake.nix" ]] || fail "Missing Home Manager flake link"
  [[ -d "$XDG_CONFIG_HOME/git/template" ]] || fail "Missing git template directory"
}

assert_links() {
  local expected_kind="$1"
  local path
  local link_target

  while IFS='|' read -r root source target; do
    if [[ -z "$root" || "$root" == \#* ]]; then
      continue
    fi

    if [[ "$root" == "termenv" ]]; then
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
    link_target="$(readlink "$path")"

    case "$expected_kind" in
      runtime)
        [[ "$link_target" == "$HOME/terminalenv/$source" ]] || fail "$path pointed to $link_target, expected $HOME/terminalenv/$source"
        ;;
      store)
        [[ "$link_target" == /nix/store/* ]] || fail "$path pointed to $link_target, expected /nix/store/*"
        ;;
      *)
        fail "Unknown expected link kind: $expected_kind"
        ;;
    esac
  done < "$MANIFEST"
}

assert_runtime_files() {
  local expected_kind="$1"
  local relative_path
  local path
  local resolved

  while IFS= read -r relative_path; do
    [[ -n "$relative_path" && "$relative_path" != \#* ]] || continue
    path="$HOME/terminalenv/$relative_path"
    [[ -e "$path" || -L "$path" ]] || fail "Missing TERMENV entry $path"

    case "$expected_kind" in
      runtime)
        [[ -e "$path" ]] || fail "Missing checkout runtime file $path"
        ;;
      store)
        resolved="$(readlink -f "$path")"
        [[ "$resolved" == /nix/store/* ]] || fail "$path resolved to $resolved, expected /nix/store/*"
        ;;
      *)
        fail "Unknown TERMENV entry kind: $expected_kind"
        ;;
    esac
  done < "$RUNTIME_FILES_MANIFEST"
}

assert_bash_works() {
  env -u TERMENV bash -i -c 'complete -p ga >/dev/null && [ "$TERMENV" = "$HOME/terminalenv" ] && [ -f "$TERMENV/home/bash/lib.sh" ]'
}

assert_profile_works() {
  env -u TERMENV bash -lc '[ "$TERMENV" = "$HOME/terminalenv" ] && [ -f "$TERMENV/home/bash/lib.sh" ]'
}

assert_runtime_root_is_checkout() {
  [[ -d "$HOME/terminalenv" ]] || fail "~/terminalenv is not a directory checkout"
  [[ ! -L "$HOME/terminalenv" ]] || fail "~/terminalenv should not be a symlink"
  [[ -f "$HOME/terminalenv/home/bash/bashrc" ]] || fail "~/terminalenv checkout is missing bash config"
}

assert_runtime_root_is_store_materialized() {
  [[ -d "$HOME/terminalenv" ]] || fail "Missing ~/terminalenv"
  [[ ! -L "$HOME/terminalenv" ]] || fail "~/terminalenv should not be a symlink"
}

assert_no_dangling_symlinks() {
  local dangling

  dangling="$({ find "$HOME" -xtype l 2>/dev/null || true; find "$XDG_CONFIG_HOME" -xtype l 2>/dev/null || true; } | sort -u)"

  if [[ -n "$dangling" ]]; then
    fail "Found dangling symlinks:${dangling}"
  fi
}

assert_termenv_references_resolve() {
  local -a scan_paths=()
  local references
  local reference
  local relative_path

  for path in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.zshrc" "$HOME/.zshenv" "$XDG_CONFIG_HOME"; do
    [[ -e "$path" ]] && scan_paths+=("$path")
  done

  references="$({ grep -RhoE '\$TERMENV(/[A-Za-z0-9._-]+)+' "${scan_paths[@]}" 2>/dev/null || true; grep -RhoE '\$\{TERMENV\}(/[A-Za-z0-9._-]+)+' "${scan_paths[@]}" 2>/dev/null || true; } | sort -u)"

  while IFS= read -r reference; do
    [[ -n "$reference" ]] || continue
    relative_path="${reference#\$TERMENV/}"
    relative_path="${relative_path#\$\{TERMENV\}/}"

    [[ -e "$HOME/terminalenv/$relative_path" ]] || fail "Missing TERMENV target for reference $reference -> $HOME/terminalenv/$relative_path"
  done <<< "$references"
}

assert_home_manager_profile_state() {
  [[ -L "$XDG_STATE_HOME/nix/profiles/home-manager" ]] || fail "Home Manager profile symlink was not created in XDG state"
}

assert_git_config_template_dir() {
  [[ "$(git config --global init.templateDir)" == "$XDG_CONFIG_HOME/git/template" ]] || fail "git init.templateDir was not configured correctly"
}

assert_idempotent_script() {
  bash "$HOME/terminalenv/mksymlinks.sh" >/dev/null
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
          ({ lib, ... }: {
            home.username = "tester";
            home.homeDirectory = "${HOME}";
            home.stateVersion = "24.11";
            ${overrides}
          })
        ];
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
  log "Testing native symlink deployment"
  bash "$HOME/terminalenv/mksymlinks.sh"
  assert_idempotent_script
  assert_links runtime
  assert_runtime_root_is_checkout
  assert_runtime_files runtime
  assert_no_dangling_symlinks
  assert_core_files_exist
  assert_profile_works
  assert_bash_works
  assert_termenv_references_resolve
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
  assert_links store
  if [[ "$expected_kind" == "runtime" ]]; then
    assert_runtime_root_is_checkout
  else
    assert_runtime_root_is_store_materialized
  fi
  assert_runtime_files "$expected_kind"
  assert_no_dangling_symlinks
  assert_core_files_exist
  assert_profile_works
  assert_bash_works
  assert_termenv_references_resolve
  assert_home_manager_profile_state
  assert_git_config_template_dir
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
  assert_links store
  assert_runtime_root_is_store_materialized
  assert_runtime_files store
  assert_no_dangling_symlinks
  assert_core_files_exist
  assert_profile_works
  assert_bash_works
  assert_termenv_references_resolve
  assert_home_manager_profile_state
  assert_git_config_template_dir
}

run_script_mode
run_home_manager_mode out-of-store runtime
run_home_manager_mode store store
run_external_flake_module_mode out-of-store runtime
run_external_flake_module_mode store store

log "All deployment models passed"
