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
REPO_ROOT="$(cd -P "$TESTS_DIR/.." >/dev/null 2>&1 && pwd)"
MANIFEST="$REPO_ROOT/symlinks.txt"
TEST_TMPDIR="${TMPDIR:-/tmp}"
TEST_ROOT="$(mktemp -d "$TEST_TMPDIR/terminalenv-tests.XXXXXX")"
IMAGE_TAG="terminalenv-deployment-tests:local"
IMAGE_ARCHIVE="${IMAGE_ARCHIVE:-}"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
CONTAINER_ROOT="/sandbox"
CONTAINER_HOME="$CONTAINER_ROOT/home"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

need_cmd bash
need_cmd podman
need_cmd nix
need_cmd readlink

build_test_image() {
  if [[ -n "$IMAGE_ARCHIVE" ]]; then
    log "Loading deployment test image"
    podman load -i "$IMAGE_ARCHIVE" >/dev/null
    return
  fi

  log "Building deployment test image"
  podman build -q -t "$IMAGE_TAG" -f "$REPO_ROOT/tests/deployments.Containerfile" "$REPO_ROOT/tests" >/dev/null
}

container_shell() {
  local sandbox_root="$1"
  shift
  local command="$*"

  podman run --rm \
    --userns=keep-id \
    --user "$HOST_UID:$HOST_GID" \
    --group-add keep-groups \
    -v /nix:/nix:ro \
    -v "$REPO_ROOT:$REPO_ROOT:ro" \
    -v "$sandbox_root:$CONTAINER_ROOT:rw" \
    -w "$CONTAINER_HOME" \
    -e HOME="$CONTAINER_HOME" \
    -e USER=tester \
    -e LOGNAME=tester \
    -e XDG_CONFIG_HOME="$CONTAINER_HOME/.config" \
    -e XDG_CACHE_HOME="$CONTAINER_HOME/.cache" \
    -e XDG_DATA_HOME="$CONTAINER_HOME/.local/share" \
    -e XDG_STATE_HOME="$CONTAINER_HOME/.local/state" \
    -e TERM=xterm-256color \
    -e COMMAND="$command" \
    "$IMAGE_TAG" \
    bash -lc "$command"
}

container_interactive_bash() {
  local sandbox_root="$1"
  shift
  local command="$*"

  podman run --rm \
    --userns=keep-id \
    --user "$HOST_UID:$HOST_GID" \
    --group-add keep-groups \
    -v /nix:/nix:ro \
    -v "$REPO_ROOT:$REPO_ROOT:ro" \
    -v "$sandbox_root:$CONTAINER_ROOT:rw" \
    -w "$CONTAINER_HOME" \
    -e HOME="$CONTAINER_HOME" \
    -e USER=tester \
    -e LOGNAME=tester \
    -e XDG_CONFIG_HOME="$CONTAINER_HOME/.config" \
    -e XDG_CACHE_HOME="$CONTAINER_HOME/.cache" \
    -e XDG_DATA_HOME="$CONTAINER_HOME/.local/share" \
    -e XDG_STATE_HOME="$CONTAINER_HOME/.local/state" \
    -e TERM=xterm-256color \
    -e COMMAND="$command" \
    "$IMAGE_TAG" \
    bash -i -c "$command"
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
  local sandbox_root="$1"
  local root="$2"
  local target="$3"

  case "$root" in
    home)
      printf '%s/home/%s\n' "$sandbox_root" "$target"
      ;;
    xdg-config)
      printf '%s/home/.config/%s\n' "$sandbox_root" "$target"
      ;;
    *)
      fail "Unknown manifest root: $root"
      ;;
  esac
}

assert_links() {
  local sandbox_root="$1"
  local expected_kind="$2"

  while IFS='|' read -r root source target; do
    local path
    local resolved
    path="$(target_path "$sandbox_root" "$root" "$target")"

    [[ -L "$path" ]] || fail "$path is not a symlink"
    resolved="$(readlink -f "$path")"

    case "$expected_kind" in
      repo)
        [[ "$resolved" == "$REPO_ROOT/$source" ]] || fail "$path resolved to $resolved, expected $REPO_ROOT/$source"
        ;;
      store)
        [[ "$resolved" == /nix/store/* ]] || fail "$path resolved to $resolved, expected /nix/store/*"
        ;;
      *)
        fail "Unknown expected link kind: $expected_kind"
        ;;
    esac
  done < <(manifest_entries)
}

assert_bash_works() {
  local sandbox_root="$1"

  container_interactive_bash "$sandbox_root" "complete -p ga >/dev/null && [ \"\$TERMENV\" = \"$CONTAINER_HOME/.config/terminalenv\" ]"
}

prepare_sandbox() {
  local name="$1"
  local sandbox_root="$TEST_ROOT/$name"

  mkdir -p "$sandbox_root/home"
  printf '%s\n' "$sandbox_root"
}

build_activation() {
  local mode="$1"

  case "$mode" in
    out-of-store)
      if [[ -n "${ACTIVATION_OUT_OF_STORE:-}" ]]; then
        printf '%s\n' "$ACTIVATION_OUT_OF_STORE"
        return
      fi
      ;;
    store)
      if [[ -n "${ACTIVATION_STORE:-}" ]]; then
        printf '%s\n' "$ACTIVATION_STORE"
        return
      fi
      ;;
    *)
      fail "Unknown Home Manager mode: $mode"
      ;;
  esac

  nix build \
    --no-link \
    --print-out-paths \
    --impure \
    --file "$REPO_ROOT/tests/home-manager-activation.nix" \
    --argstr mode "$mode" \
    --argstr homeDirectory "$CONTAINER_HOME" \
    --argstr repoRoot "$REPO_ROOT"
}

test_script_mode() {
  local sandbox_root
  sandbox_root="$(prepare_sandbox script)"

  log "Testing native symlink deployment"
  container_shell "$sandbox_root" "TERMENV=\"$REPO_ROOT\" \"$REPO_ROOT/mksymlinks.sh\""
  assert_links "$sandbox_root" repo
  assert_bash_works "$sandbox_root"
}

test_home_manager_mode() {
  local mode="$1"
  local expected_kind="$2"
  local sandbox_root
  local activation

  sandbox_root="$(prepare_sandbox home-manager-$mode)"
  log "Testing Home Manager deployment ($mode)"
  activation="$(build_activation "$mode")"
  container_shell "$sandbox_root" "$activation/activate --driver-version 1"
  assert_links "$sandbox_root" "$expected_kind"
  assert_bash_works "$sandbox_root"
}

build_test_image
test_script_mode
test_home_manager_mode out-of-store repo
test_home_manager_mode store store

log "All deployment models passed"
