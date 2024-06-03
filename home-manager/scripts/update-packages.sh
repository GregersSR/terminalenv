#!/usr/bin/env bash

command -v apt-get && sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y
command -v snap && sudo snap refresh
