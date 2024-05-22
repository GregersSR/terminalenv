#!/usr/bin/env bash
set -e
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_HOME_FILE="${CONFIG_HOME}/home-manager/home.nix"
SCRIPT_DIR="$(dirname $(realpath $0))"
REPO_FILE="$SCRIPT_DIR/home.nix"

if [[ -L "$CONFIG_HOME_FILE" ]]
then
	if [[ "$(realpath ${CONFIG_HOME_FILE})" == "$REPO_FILE" ]]
	then
		echo "Link already exists, did nothing"
		exit 0
	else
		echo "Link already exists but points elsewhere, aborting"
		exit 1
	fi
elif [[ -e "$CONFIG_HOME_FILE" ]]
then
	# file exists
	echo "File exists and is not a link. Moving aside in order to link."
	mv "$CONFIG_HOME_FILE" "${CONFIG_HOME_FILE}.bak_$(date -Iseconds)"
fi
ln -s "$REPO_FILE" "$CONFIG_HOME_FILE"
