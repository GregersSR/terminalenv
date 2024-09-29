#!/usr/bin/env bash

function checkAndPrint {
	local cmd="$1"
	command -v "$cmd" >/dev/null && printf "\n\n====== Upgrading: ${cmd} ======\n\n"
}

checkAndPrint apt-get && sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y
checkAndPrint snap && sudo snap refresh
checkAndPrint fwupdmgr && sudo fwupdmgr update
checkAndPrint flatpak && flatpak update
checkAndPrint pacstall && sudo pacstall -U && sudo pacstall -Up
