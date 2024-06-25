#!/usr/bin/env bash
set -e
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_HOME_FILE="${CONFIG_HOME}/home-manager/flake.nix"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
REPO_FILE="$SCRIPT_DIR/flake.nix"

link_file() {
	target="$1"
	dst_link="$2"
	if [[ -L "$dst_link" ]]
	then
		if [[ "$(realpath "${dst_link}")" == "$target" ]]
		then
			echo "Link already exists, did nothing"
			exit 0
		else
			echo "Link already exists but points elsewhere, aborting"
			exit 1
		fi
	elif [[ -e "$dst_link" ]]
	then
		# file exists
		echo "File exists and is not a link. Moving aside in order to link."
		mv "$dst_link" "${dst_link}.bak_$(date -Iseconds)"
	fi
	ln -s "$target" "$dst_link"

}

mkdir -p "${CONFIG_HOME}/home-manager"
link_file "$REPO_FILE" "$CONFIG_HOME_FILE"
