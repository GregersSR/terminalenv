#!/usr/bin/env bash

set -euo pipefail

resolve_path () {
    local source_path="$1"
    local link_dir

    while [ -L "$source_path" ]; do
        link_dir="$(cd -P "$(dirname "$source_path")" >/dev/null 2>&1 && pwd)"
        source_path="$(readlink "$source_path")"
        if [[ "$source_path" != /* ]]; then
            source_path="$link_dir/$source_path"
        fi
    done

    (
        cd -P "$(dirname "$source_path")" >/dev/null 2>&1 || exit 1
        printf '%s/%s\n' "$(pwd)" "$(basename "$source_path")"
    )
}

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

if ! command -v stow >/dev/null 2>&1; then
    fail "stow is required for native dotfiles deployment"
fi

REPO_ROOT="$(dirname "$(resolve_path "${BASH_SOURCE[0]}")")"

if [[ ! -d "$REPO_ROOT/home" ]]; then
    fail "dotfiles package directory not found: $REPO_ROOT/home"
fi

packages=(home)

if [[ "$#" -gt 0 ]]; then
    packages+=("$@")
fi

for package in "${packages[@]}"; do
    if [[ ! -d "$REPO_ROOT/$package" ]]; then
        fail "dotfiles package directory not found: $REPO_ROOT/$package"
    fi
done

for package in "${packages[@]}"; do
    package_args=(--dir "$REPO_ROOT" --target "$HOME" --restow "$package")

    if [[ "$package" == repos ]]; then
        package_args=(--dotfiles --no-folding "${package_args[@]}")
    fi

    stow "${package_args[@]}"
done
