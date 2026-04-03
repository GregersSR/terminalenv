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
  if [[ -n "${cid:-}" ]]; then
    podman rm -f "$cid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

need_cmd podman

printf '==> Ensuring base image %s\n' "$BASE_NIX_IMAGE"
if ! podman image exists "$BASE_NIX_IMAGE"; then
  podman pull "$BASE_NIX_IMAGE" >/dev/null
fi

bash_path="$(podman image inspect "$BASE_NIX_IMAGE" --format '{{index .Config.Cmd 0}}')"
[[ -n "$bash_path" ]] || fail "Could not determine bash path for $BASE_NIX_IMAGE"

printf '==> Warming Nix store in a temporary container\n'
cid="$(podman create --entrypoint "$bash_path" -v "$REPO_ROOT:/repo:ro" "$BASE_NIX_IMAGE" /repo/tests/verify-deployment.sh)"
if [[ "$VERBOSE" == "1" ]]; then
  podman start -a "$cid"
else
  output_file="$(mktemp)"
  trap 'rm -f "$output_file"; if [[ -n "${cid:-}" ]]; then podman rm -f "$cid" >/dev/null 2>&1 || true; fi' EXIT

  if podman start -a "$cid" >"$output_file" 2>&1; then
    grep '^==>' "$output_file" || true
  else
    cat "$output_file" >&2
    exit 1
  fi
fi

printf '==> Saving warmed image as %s\n' "$CACHED_NIX_IMAGE"
podman image rm -f "$CACHED_NIX_IMAGE" >/dev/null 2>&1 || true
podman commit --change "ENTRYPOINT [\"$bash_path\"]" --change 'CMD []' "$cid" "$CACHED_NIX_IMAGE" >/dev/null

printf '==> Test image ready: %s\n' "$CACHED_NIX_IMAGE"
