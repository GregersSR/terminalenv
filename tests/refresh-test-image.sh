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
CONTAINERFILE_PATH="$TESTS_DIR/Containerfile"
CONTAINERIGNORE_PATH="$TESTS_DIR/.containerignore"
BASE_NIX_IMAGE="docker.io/nixos/nix@sha256:0b1530edf840d9af519c7f3970cafbbed68d9d9554a83cc9adc04099753117e1"
CACHED_NIX_IMAGE="localhost/terminalenv-tests:latest"
IMAGE_COPY_TMPDIR="${IMAGE_COPY_TMPDIR:-/tmp}"
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
mkdir -p "$IMAGE_COPY_TMPDIR"

printf '==> Ensuring base image %s\n' "$BASE_NIX_IMAGE"
if ! podman image exists "$BASE_NIX_IMAGE"; then
  podman pull "$BASE_NIX_IMAGE" >/dev/null
fi

printf '==> Building warmed test image %s\n' "$CACHED_NIX_IMAGE"
printf '==> Using image copy temp dir %s\n' "$IMAGE_COPY_TMPDIR"
podman image rm -f "$CACHED_NIX_IMAGE" >/dev/null 2>&1 || true

if [[ "$VERBOSE" == "1" ]]; then
  TMPDIR="$IMAGE_COPY_TMPDIR" podman build --build-arg "BASE_NIX_IMAGE=$BASE_NIX_IMAGE" --no-cache --layers=false --squash-all --tag "$CACHED_NIX_IMAGE" --file "$CONTAINERFILE_PATH" --ignorefile "$CONTAINERIGNORE_PATH" "$REPO_ROOT"
else
  output_file="$(mktemp)"

  if TMPDIR="$IMAGE_COPY_TMPDIR" podman build --build-arg "BASE_NIX_IMAGE=$BASE_NIX_IMAGE" --no-cache --layers=false --squash-all --tag "$CACHED_NIX_IMAGE" --file "$CONTAINERFILE_PATH" --ignorefile "$CONTAINERIGNORE_PATH" "$REPO_ROOT" >"$output_file" 2>&1; then
    grep '^==>' "$output_file" || true
  else
    cat "$output_file" >&2
    exit 1
  fi
fi

printf '==> Test image ready: %s\n' "$CACHED_NIX_IMAGE"
