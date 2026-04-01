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
NIX_IMAGE="docker.io/nixos/nix@sha256:0b1530edf840d9af519c7f3970cafbbed68d9d9554a83cc9adc04099753117e1"
CONTAINER_BASH=""

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

need_cmd bash
need_cmd podman

printf '==> Ensuring test image %s\n' "$NIX_IMAGE"
if ! podman image exists "$NIX_IMAGE"; then
  podman pull "$NIX_IMAGE" >/dev/null
fi
CONTAINER_BASH="$(podman image inspect "$NIX_IMAGE" --format '{{index .Config.Cmd 0}}')"
[[ -n "$CONTAINER_BASH" ]] || fail "Could not determine bash path for $NIX_IMAGE"

printf '==> Running deployment harness in isolated Nix container\n'
podman run --rm \
  --entrypoint "$CONTAINER_BASH" \
  -v "$REPO_ROOT:/repo:ro" \
  "$NIX_IMAGE" \
  /repo/tests/verify-deployment.sh
