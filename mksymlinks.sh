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

if [[ ! -d "$REPO_ROOT/dotpkgs" ]]; then
    fail "dotfiles packages directory not found: $REPO_ROOT/dotpkgs"
fi

packages=()
for pkg_dir in "$REPO_ROOT/dotpkgs"/*/; do
    packages+=("$(basename "$pkg_dir")")
done

if [[ "$#" -gt 0 ]]; then
    packages+=("$@")
fi

declare -A seen_packages=()
unique_packages=()
for package in "${packages[@]}"; do
    if [[ -z "${seen_packages[$package]+x}" ]]; then
        seen_packages[$package]=1
        unique_packages+=("$package")
    fi
done
packages=("${unique_packages[@]}")

for package in "${packages[@]}"; do
    if [[ ! -d "$REPO_ROOT/dotpkgs/$package" ]]; then
        fail "dotfiles package directory not found: $REPO_ROOT/dotpkgs/$package"
    fi
done

link_target_abs() {
    local link_path="$1"
    local target
    local parent

    target="$(readlink "$link_path")"
    if [[ "$target" == /* ]]; then
        readlink -m "$target"
    else
        parent="$(cd -P "$(dirname "$link_path")" >/dev/null 2>&1 && pwd)"
        readlink -m "$parent/$target"
    fi
}

remove_legacy_link_if_needed() {
    local link_path="$1"
    local target_abs
    local legacy_package
    local legacy_root

    [[ -L "$link_path" ]] || return 0

    target_abs="$(link_target_abs "$link_path")"
    for legacy_package in home repos opencode; do
        legacy_root="$(readlink -m "$REPO_ROOT/$legacy_package")"
        if [[ "$target_abs" == "$legacy_root" || "$target_abs" == "$legacy_root/"* ]]; then
            rm "$link_path"
            return 0
        fi
    done
}

remove_legacy_links_for_path() {
    local relative_path="$1"
    local current="$HOME"
    local segment
    local -a path_segments

    IFS=/ read -r -a path_segments <<< "$relative_path"
    for segment in "${path_segments[@]}"; do
        current="$current/$segment"
        remove_legacy_link_if_needed "$current"
    done
}

for package in "${packages[@]}"; do
    while IFS= read -r -d '' package_file; do
        remove_legacy_links_for_path "${package_file#"$REPO_ROOT/dotpkgs/$package/"}"
    done < <(find "$REPO_ROOT/dotpkgs/$package" -type f -print0)
done

for package in "${packages[@]}"; do
    package_args=(--dir "$REPO_ROOT/dotpkgs" --target "$HOME" --restow "$package")

    stow "${package_args[@]}"
done
