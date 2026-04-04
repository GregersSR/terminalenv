#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  if [[ "$SCRIPT_PATH" != /* ]]; then
    SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
  fi
done
TESTS_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd -P "$TESTS_DIR/.." >/dev/null 2>&1 && pwd)}"
REPO_HOME="$REPO_ROOT/home"
TEST_HOME="${TEST_HOME:-/tmp/terminalenv-test-home}"

: "${ACTIVATION_OUT_OF_STORE:?ACTIVATION_OUT_OF_STORE must be set}"
: "${ACTIVATION_STORE:?ACTIVATION_STORE must be set}"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

home_tree_entries() {
  (
    cd "$REPO_HOME"
    find . -type f -printf '%P\n' | sort
  )
}

installed_path() {
  printf '%s/%s\n' "$TEST_HOME" "$1"
}

reset_home() {
  rm -rf "$TEST_HOME"
  mkdir -p "$TEST_HOME"
}

shell_env() {
  export HOME="$TEST_HOME"
  export USER=tester
  export LOGNAME=tester
  export XDG_CONFIG_HOME="$TEST_HOME/.config"
  export XDG_CACHE_HOME="$TEST_HOME/.cache"
  export XDG_DATA_HOME="$TEST_HOME/.local/share"
  export XDG_STATE_HOME="$TEST_HOME/.local/state"
  export TERM=xterm-256color
}

seed_checkout() {
  mkdir -p "$TEST_HOME/terminalenv"
  cp -a "$REPO_ROOT/." "$TEST_HOME/terminalenv"
  chmod -R u+w "$TEST_HOME/terminalenv" 2>/dev/null || true
  rm -rf "$TEST_HOME/terminalenv/result"
}

assert_links() {
  local expected_kind="$1"

  while IFS= read -r relative_path; do
    local path
    local resolved

    path="$(installed_path "$relative_path")"
    [[ -L "$path" ]] || fail "$path is not a symlink"
    resolved="$(readlink -f "$path" 2>/dev/null || true)"
    [[ -n "$resolved" ]] || fail "$path is unreadable"

    case "$expected_kind" in
      runtime)
        [[ "$resolved" == "$TEST_HOME/terminalenv/home/$relative_path" ]] || fail "$path resolved to $resolved, expected $TEST_HOME/terminalenv/home/$relative_path"
        ;;
      store)
        [[ "$resolved" == /nix/store/* ]] || fail "$path resolved to $resolved, expected /nix/store/*"
        ;;
      *)
        fail "Unknown expected link kind: $expected_kind"
        ;;
    esac
  done < <(home_tree_entries)
}

assert_bash_works() {
  if ! HOME="$TEST_HOME" \
    USER=tester \
    LOGNAME=tester \
    XDG_CONFIG_HOME="$TEST_HOME/.config" \
    XDG_CACHE_HOME="$TEST_HOME/.cache" \
    XDG_DATA_HOME="$TEST_HOME/.local/share" \
    XDG_STATE_HOME="$TEST_HOME/.local/state" \
    TERM=xterm-256color \
    bash -i -c 'complete -p ga >/dev/null && [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/bash/lib.sh" ]'; then
    fail "Interactive bash check failed for $TEST_HOME"
  fi
}

assert_core_paths() {
  [[ -L "$TEST_HOME/.bashrc" ]] || fail "Missing ~/.bashrc symlink"
  [[ -L "$TEST_HOME/.profile" ]] || fail "Missing ~/.profile symlink"
  [[ -L "$TEST_HOME/.local/bin/update-packages" ]] || fail "Missing update-packages symlink"
  [[ -x "$TEST_HOME/.local/bin/update-packages" ]] || fail "update-packages is not executable"
  [[ -L "$TEST_HOME/.config/nvim/init.vim" ]] || fail "Missing ~/.config/nvim/init.vim symlink"
  [[ ! -e "$TEST_HOME/.config/nvim/init.lua" ]] || fail "Unexpected ~/.config/nvim/init.lua"
}

assert_profile_works() {
  if ! HOME="$TEST_HOME" \
    USER=tester \
    LOGNAME=tester \
    XDG_CONFIG_HOME="$TEST_HOME/.config" \
    XDG_CACHE_HOME="$TEST_HOME/.cache" \
    XDG_DATA_HOME="$TEST_HOME/.local/share" \
    XDG_STATE_HOME="$TEST_HOME/.local/state" \
    TERM=xterm-256color \
    bash -lc 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) exit 1 ;; esac'; then
    fail "Login shell profile check failed for $TEST_HOME"
  fi
}

run_script_mode() {
  log "Testing native symlink deployment in Nix check sandbox"
  reset_home
  shell_env
  seed_checkout
  bash "$TEST_HOME/terminalenv/mksymlinks.sh"
  bash "$TEST_HOME/terminalenv/mksymlinks.sh" >/dev/null
  assert_links runtime
  assert_core_paths
  assert_profile_works
  assert_bash_works
}

assert_generation_entries() {
  local generation="$1"

  while IFS= read -r relative_path; do
    local home_files_path

    home_files_path="$generation/home-files/$relative_path"

    [[ -e "$home_files_path" || -L "$home_files_path" ]] || fail "Expected generated path missing: $home_files_path"
  done < <(home_tree_entries)
}

run_home_manager_mode() {
  local mode="$1"
  local generation="$2"

  log "Testing Home Manager deployment ($mode) generation output"
  if [[ "$mode" == "store" ]]; then
    assert_generation_entries "$generation"
  else
    [[ -f "$generation/activate" ]] || fail "Missing activation script for out-of-store mode"
    grep -q -- '--no-folding --restow home' "$generation/activate" || fail "Out-of-store activation does not restow home/"
    [[ ! -e "$generation/home-files/.bashrc" ]] || fail "Out-of-store generation should not materialize ~/.bashrc"
  fi

  [[ -e "$generation/home-files/.config/nvim/hm-generated.lua" ]] || fail "Missing generated Home Manager nvim helper"
  [[ ! -e "$generation/home-files/.config/nvim/init.lua" ]] || fail "Unexpected generated Home Manager init.lua"
}

run_script_mode
run_home_manager_mode out-of-store "$ACTIVATION_OUT_OF_STORE"
run_home_manager_mode store "$ACTIVATION_STORE"

log "All Nix check deployment models passed"
