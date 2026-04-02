#!/usr/bin/env bash

set -euo pipefail

EXIT_CODE=0

error () {
    printf '%s\n' "$*" >&2
    EXIT_CODE=1
}

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

if [[ -z "${TERMENV:-}" ]]; then
    TERMENV="$(dirname "$(resolve_path "${BASH_SOURCE[0]}")")"
fi

SYMLINKS_FILE="${TERMENV}/symlinks.txt"
DOT_CONFIG="${XDG_CONFIG_HOME:-${HOME}/.config}"

target_path_for_root () {
    local root="$1"
    local relative_path="$2"

    case "$root" in
        home)
            printf '%s/%s\n' "$HOME" "$relative_path"
            ;;
        xdg-config)
            printf '%s/%s\n' "$DOT_CONFIG" "$relative_path"
            ;;
        *)
            error "ERROR: Unknown target root '$root' in $SYMLINKS_FILE"
            return 1
            ;;
    esac
}

link () {
    local target="$1"
    local link_name="$2"
    local target_abs
    local current_target

    target_abs="$(resolve_path "$target")"
    printf '%s -> %s' "$link_name" "$target"

    if [[ -e "$link_name" || -L "$link_name" ]]; then
        if [[ -L "$link_name" ]]; then
            current_target="$(resolve_path "$link_name" 2>/dev/null || true)"
            if [[ "$target_abs" != "$current_target" ]]; then
                error ". ERROR: $link_name is already a link that points to $current_target."
            else
                printf '.\n'
            fi
        else
            error ". ERROR: $link_name already exists!"
        fi
    else
        if ! mkdir -p "$(dirname "$link_name")"; then
            error ". ERROR: Cannot create $(dirname "$link_name")!"
        fi
        printf '.\n'
        ln -s "$target" "$link_name" || EXIT_CODE=1
    fi
}

ensure_runtime_root () {
    local runtime_root="$HOME/terminalenv"
    local target_abs
    local current_target

    target_abs="$(resolve_path "$TERMENV")"
    printf '%s -> %s' "$runtime_root" "$TERMENV"

    if [[ -e "$runtime_root" || -L "$runtime_root" ]]; then
        current_target="$(resolve_path "$runtime_root" 2>/dev/null || true)"
        if [[ "$current_target" == "$target_abs" ]]; then
            printf '.\n'
        else
            error ". ERROR: $runtime_root already exists and resolves to $current_target."
        fi
    else
        printf '.\n'
        ln -s "$TERMENV" "$runtime_root" || EXIT_CODE=1
    fi
}

if [[ ! -f "$SYMLINKS_FILE" ]]; then
    error "ERROR: symlink manifest not found: $SYMLINKS_FILE"
    exit 1
fi

ensure_runtime_root

while IFS='|' read -r root source target; do
    if [[ -z "$root" || "$root" == \#* ]]; then
        continue
    fi

    if [[ -z "$source" || -z "$target" ]]; then
        error "ERROR: Invalid symlink entry in $SYMLINKS_FILE: $root|$source|$target"
        continue
    fi

    link "${TERMENV}/${source}" "$(target_path_for_root "$root" "$target")"
done < "$SYMLINKS_FILE"

exit "$EXIT_CODE"
