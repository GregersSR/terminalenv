#!/usr/bin/env bash

set -e

if [[ "$EUID" != 0 ]]
then
	echo "Must be run as root." >&2
	exit 1
fi

cleanup () {
	ip route del default dev tun-dtu
	kill "$(<$PID_FILE)" || kill -9 "$(<$PID_FILE)" || true
}

PID_FILE="$(mktemp)"
openconnect --background --pid-file="$PID_FILE" --interface=tun-dtu --os=win --useragent=AnyConnect --user=s243878 https://vpn.dtu.dk
trap cleanup EXIT
while [ ! -d /proc/sys/net/ipv6/conf/tun-dtu ]
do
	echo "Waiting for tun-dtu to come up . . ."
	sleep 1
done
sysctl -w net.ipv6.conf.tun-dtu.disable_ipv6=1
ip route add default dev tun-dtu
echo "Connected. Pres Ctrl-C to disconnect."
read -r -d '' _ </dev/tty
