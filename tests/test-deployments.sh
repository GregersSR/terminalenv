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
CACHED_NIX_IMAGE="localhost/terminalenv-tests:latest"
output_file=""

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      printf 'Usage: %s [-v|--verbose]\n' "$(basename "$0")"
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

cleanup() {
  if [[ -n "$output_file" ]]; then
    rm -f "$output_file"
  fi
}
trap cleanup EXIT

need_cmd podman

if ! podman image exists "$CACHED_NIX_IMAGE"; then
  fail "Cached test image missing: $CACHED_NIX_IMAGE. Run tests/refresh-test-image.sh first."
fi

printf '==> Using cached test image %s\n' "$CACHED_NIX_IMAGE"

printf '==> Running deployment harness in isolated Nix container\n'
if [[ "$VERBOSE" == "1" ]]; then
  podman run --rm \
    -v "$REPO_ROOT:/repo:ro" \
    "$CACHED_NIX_IMAGE"
else
  output_file="$(mktemp)"

  if podman run --rm \
    -v "$REPO_ROOT:/repo:ro" \
    "$CACHED_NIX_IMAGE" >"$output_file" 2>&1; then
    grep '^==>' "$output_file" || true
  else
    cat "$output_file" >&2
    exit 1
  fi
fi
