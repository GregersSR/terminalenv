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
MANIFEST="$REPO_ROOT/symlinks.txt"
TEST_HOME="${TEST_HOME:-/tmp/terminalenv-test-home}"

: "${ACTIVATION_OUT_OF_STORE:?ACTIVATION_OUT_OF_STORE must be set}"
: "${ACTIVATION_STORE:?ACTIVATION_STORE must be set}"
: "${EXPECTED_OUT_OF_STORE_ROOT:?EXPECTED_OUT_OF_STORE_ROOT must be set}"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

manifest_entries() {
  while IFS='|' read -r root source target; do
    if [[ -z "$root" || "$root" == \#* ]]; then
      continue
    fi
    printf '%s|%s|%s\n' "$root" "$source" "$target"
  done < "$MANIFEST"
}

target_path() {
  local root="$1"
  local target="$2"

  case "$root" in
    home)
      printf '%s/%s\n' "$TEST_HOME" "$target"
      ;;
    xdg-config)
      printf '%s/.config/%s\n' "$TEST_HOME" "$target"
      ;;
    *)
      fail "Unknown manifest root: $root"
      ;;
  esac
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

assert_links() {
  local expected_kind="$1"

  while IFS='|' read -r root source target; do
    local path
    local resolved
    local expected

    path="$(target_path "$root" "$target")"
    [[ -L "$path" ]] || fail "$path is not a symlink"
    resolved="$(readlink -f "$path" 2>/dev/null || true)"
    [[ -n "$resolved" ]] || fail "$path is dangling or unreadable"
    expected="$EXPECTED_OUT_OF_STORE_ROOT/$source"

    case "$expected_kind" in
      repo)
        [[ "$resolved" == "$expected" ]] || fail "$path resolved to $resolved, expected $expected"
        ;;
      store)
        [[ "$resolved" == /nix/store/* ]] || fail "$path resolved to $resolved, expected /nix/store/*"
        [[ "$resolved" != "$expected" ]] || fail "$path unexpectedly resolved to source path $expected in store mode"
        ;;
      *)
        fail "Unknown expected link kind: $expected_kind"
        ;;
    esac
  done < <(manifest_entries)
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
    bash -i -c 'complete -p ga >/dev/null && [ "$TERMENV" = "$XDG_CONFIG_HOME/terminalenv" ]'; then
    fail "Interactive bash check failed for $TEST_HOME"
  fi
}

assert_core_paths() {
  [[ -L "$TEST_HOME/.bashrc" ]] || fail "Missing ~/.bashrc symlink"
  [[ -L "$TEST_HOME/.profile" ]] || fail "Missing ~/.profile symlink"
  [[ -L "$TEST_HOME/.local/bin/update-packages" ]] || fail "Missing update-packages symlink"
  [[ -x "$TEST_HOME/.local/bin/update-packages" ]] || fail "update-packages is not executable"
  [[ -L "$TEST_HOME/.config/terminalenv/bash" ]] || fail "Missing terminalenv bash symlink"
  [[ -f "$TEST_HOME/.config/terminalenv/bash/lib.sh" ]] || fail "Missing bash support file"
  [[ -f "$TEST_HOME/.config/terminalenv/bash/completions/git" ]] || fail "Missing vendored git completion script"
  [[ -L "$TEST_HOME/.config/terminalenv/nvim" ]] || fail "Missing terminalenv nvim symlink"
  [[ -f "$TEST_HOME/.config/terminalenv/nvim/settings.vim" ]] || fail "Missing nvim settings file"
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
    bash -lc '[ "$TERMENV" = "$XDG_CONFIG_HOME/terminalenv" ]'; then
    fail "Login shell profile check failed for $TEST_HOME"
  fi
}

run_script_mode() {
  log "Testing native symlink deployment in Nix check sandbox"
  reset_home
  shell_env
  TERMENV="$EXPECTED_OUT_OF_STORE_ROOT" bash "$REPO_ROOT/mksymlinks.sh"
  TERMENV="$EXPECTED_OUT_OF_STORE_ROOT" bash "$REPO_ROOT/mksymlinks.sh" >/dev/null
  assert_links repo
  assert_core_paths
  assert_profile_works
  assert_bash_works
}

assert_generation_entries() {
  local generation="$1"

  while IFS='|' read -r root source target; do
    local home_files_path

    case "$root" in
      home)
        home_files_path="$generation/home-files/$target"
        ;;
      xdg-config)
        home_files_path="$generation/home-files/.config/$target"
        ;;
      *)
        fail "Unknown manifest root: $root"
        ;;
    esac

    [[ -e "$home_files_path" || -L "$home_files_path" ]] || fail "Expected generated path missing: $home_files_path"
  done < <(manifest_entries)

}

run_home_manager_mode() {
  local mode="$1"
  local generation="$2"

  log "Testing Home Manager deployment ($mode) generation output"
  assert_generation_entries "$generation"
}

run_script_mode
run_home_manager_mode out-of-store "$ACTIVATION_OUT_OF_STORE"
run_home_manager_mode store "$ACTIVATION_STORE"

log "All Nix check deployment models passed"
