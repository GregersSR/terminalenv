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
BASE_NIX_IMAGE="docker.io/nixos/nix@sha256:0b1530edf840d9af519c7f3970cafbbed68d9d9554a83cc9adc04099753117e1"
CACHED_NIX_IMAGE="localhost/terminalenv-tests:latest"
NIX_IMAGE=""
CONTAINER_BASH=""

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

need_cmd bash
need_cmd podman

if podman image exists "$CACHED_NIX_IMAGE"; then
  NIX_IMAGE="$CACHED_NIX_IMAGE"
else
  NIX_IMAGE="$BASE_NIX_IMAGE"
fi

printf '==> Ensuring test image %s\n' "$NIX_IMAGE"
if ! podman image exists "$NIX_IMAGE"; then
  podman pull "$NIX_IMAGE" >/dev/null
fi
CONTAINER_BASH="$(podman image inspect "$NIX_IMAGE" --format '{{if .Config.Entrypoint}}{{index .Config.Entrypoint 0}}{{else}}{{index .Config.Cmd 0}}{{end}}')"
[[ -n "$CONTAINER_BASH" ]] || fail "Could not determine bash path for $NIX_IMAGE"

printf '==> Running deployment harness in isolated Nix container\n'
if [[ "$VERBOSE" == "1" ]]; then
  podman run --rm \
    --entrypoint "$CONTAINER_BASH" \
    -v "$REPO_ROOT:/repo:ro" \
    "$NIX_IMAGE" \
    /repo/tests/verify-deployment.sh
else
  output_file="$(mktemp)"
  trap 'rm -f "$output_file"' EXIT

  if podman run --rm \
    --entrypoint "$CONTAINER_BASH" \
    -v "$REPO_ROOT:/repo:ro" \
    "$NIX_IMAGE" \
    /repo/tests/verify-deployment.sh >"$output_file" 2>&1; then
    grep '^==>' "$output_file" || true
  else
    cat "$output_file" >&2
    exit 1
  fi
fi
