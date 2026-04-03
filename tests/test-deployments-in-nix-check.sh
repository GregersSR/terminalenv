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
RUNTIME_FILES_MANIFEST="$REPO_ROOT/runtime-files.txt"
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
  unset TERMENV
}

seed_checkout() {
  mkdir -p "$TEST_HOME/terminalenv"
  cp -a "$REPO_ROOT/." "$TEST_HOME/terminalenv"
  chmod -R u+w "$TEST_HOME/terminalenv" 2>/dev/null || true
  rm -rf "$TEST_HOME/terminalenv/result"
}

assert_links() {
  local expected_kind="$1"

  while IFS='|' read -r root source target; do
    local path
    local link_target

    [[ "$root" == "termenv" ]] && continue
    path="$(target_path "$root" "$target")"
    [[ -L "$path" ]] || fail "$path is not a symlink"
    link_target="$(readlink "$path" 2>/dev/null || true)"
    [[ -n "$link_target" ]] || fail "$path is unreadable"

    case "$expected_kind" in
      runtime)
        [[ "$link_target" == "$TEST_HOME/terminalenv/$source" ]] || fail "$path pointed to $link_target, expected $TEST_HOME/terminalenv/$source"
        ;;
      store)
        [[ "$link_target" == /nix/store/* ]] || fail "$path pointed to $link_target, expected /nix/store/*"
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
    env -u TERMENV bash -i -c 'complete -p ga >/dev/null && [ "$TERMENV" = "$HOME/terminalenv" ]'; then
    fail "Interactive bash check failed for $TEST_HOME"
  fi
}

assert_runtime_root_is_checkout() {
  [[ -d "$TEST_HOME/terminalenv" ]] || fail "Missing ~/terminalenv checkout"
  [[ ! -L "$TEST_HOME/terminalenv" ]] || fail "~/terminalenv should not be a symlink"
}

assert_runtime_root_is_store_materialized() {
  [[ -d "$TEST_HOME/terminalenv" ]] || fail "Missing ~/terminalenv runtime root"
  [[ ! -L "$TEST_HOME/terminalenv" ]] || fail "~/terminalenv should not be a symlink"
}

assert_runtime_files() {
  local expected_kind="$1"
  local relative_path
  local path
  local resolved

  while IFS= read -r relative_path; do
    [[ -n "$relative_path" && "$relative_path" != \#* ]] || continue
    path="$TEST_HOME/terminalenv/$relative_path"
    [[ -e "$path" || -L "$path" ]] || fail "Missing TERMENV entry $path"

    case "$expected_kind" in
      runtime)
        [[ -e "$path" ]] || fail "Missing checkout runtime file $path"
        ;;
      store)
        resolved="$(readlink -f "$path")"
        [[ "$resolved" == /nix/store/* ]] || fail "$path resolved to $resolved, expected /nix/store/*"
        ;;
    esac
  done < "$RUNTIME_FILES_MANIFEST"
}

assert_core_paths() {
  [[ -L "$TEST_HOME/.bashrc" ]] || fail "Missing ~/.bashrc symlink"
  [[ -L "$TEST_HOME/.profile" ]] || fail "Missing ~/.profile symlink"
  [[ -L "$TEST_HOME/.local/bin/update-packages" ]] || fail "Missing update-packages symlink"
  [[ -x "$TEST_HOME/.local/bin/update-packages" ]] || fail "update-packages is not executable"
  [[ -e "$TEST_HOME/terminalenv" ]] || fail "Missing ~/terminalenv runtime root"
  [[ -f "$TEST_HOME/terminalenv/home/bash/lib.sh" ]] || fail "Missing bash support file"
  [[ -f "$TEST_HOME/terminalenv/home/bash/completions/git" ]] || fail "Missing vendored git completion script"
  [[ -f "$TEST_HOME/terminalenv/home/nvim/settings.vim" ]] || fail "Missing nvim settings file"
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
    env -u TERMENV bash -lc '[ "$TERMENV" = "$HOME/terminalenv" ]'; then
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
  assert_runtime_root_is_checkout
  assert_runtime_files runtime
  assert_core_paths
  assert_profile_works
  assert_bash_works
}

assert_generation_entries() {
  local generation="$1"
  local mode="$2"

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
  assert_generation_entries "$generation" "$mode"
}

run_script_mode
run_home_manager_mode out-of-store "$ACTIVATION_OUT_OF_STORE"
run_home_manager_mode store "$ACTIVATION_STORE"

log "All Nix check deployment models passed"
