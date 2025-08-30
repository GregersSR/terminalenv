#!/usr/bin/env bash

set -e

EXIT_CODE=0

error () {
    2>&1 echo "$@"
    EXIT_CODE=1
}

if [[ -z "$TERMENV" ]]; then
    TERMENV="$(realpath $(dirname $BASH_SOURCE[0]))"
fi

# l TARGET LINK_NAME (ie. make a symlink at path LINK_NAME pointing to TARGET)
link () {
    TARGET="$1"
    LINK_NAME="$2"
    TARGET_ABS="$(realpath $TARGET || $TARGET)"
    2>&1 printf "%s -> %s" "$LINK_NAME" "$TARGET"
    # the -L handles broken symlinks
    if [[ -e "$LINK_NAME" || -L "$LINK_NAME" ]]; then
        if [[ -L "$LINK_NAME" ]]; then
            if [[ "$TARGET_ABS" != "$(readlink $LINK_NAME)" ]]; then
                error ". ERROR: $LINK_NAME is already a link that points to $(readlink ${LINK_NAME})."
            else
                # link already exists as we want.
                echo .
            fi
        else
            error ". ERROR: $LINK_NAME already exists!"
        fi
    else
        # LINK_NAME does not exist. Ensure parent directory does.
        if ! mkdir -p "$(dirname ${LINK_NAME})" ; then
            error ". ERROR: Cannot create $(dirname ${LINK_NAME})!"
        fi
        echo "."
        ln -s "$TARGET" "$LINK_NAME" || EXIT_CODE=1
    fi
}

DOT_CONFIG="${XDG_CONFIG_HOME:-${HOME}/.config}"

link "${TERMENV}/home/profile" "${HOME}/.profile"
link "${TERMENV}/flake.nix" "${DOT_CONFIG}/home-manager/flake.nix"

exit $EXIT_CODE
