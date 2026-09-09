#!/usr/bin/env bash

set -euo pipefail

config_file="${SVU_POWER_CONFIG:-$HOME/.config/svu-power/config}"
if [[ -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file"
fi

: "${SVU_WAKE_MAC:?Set SVU_WAKE_MAC in $config_file}"
SVU_WAKE_BROADCAST="${SVU_WAKE_BROADCAST:-192.168.0.255}"

if [[ ! "$SVU_WAKE_MAC" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]; then
    echo "Invalid SVU_WAKE_MAC in $config_file" >&2
    exit 2
fi

for _ in {1..5}; do
    /usr/bin/perl -MSocket -e '
        my ($mac, $host) = @ARGV;
        $mac =~ s/://g;
        my $packet = chr(255) x 6 . pack("H*", $mac x 16);
        socket(my $socket, PF_INET, SOCK_DGRAM, getprotobyname("udp"))
            or die "socket: $!";
        setsockopt($socket, SOL_SOCKET, SO_BROADCAST, 1)
            or die "broadcast: $!";
        send($socket, $packet, 0, sockaddr_in(9, inet_aton($host)))
            or die "send: $!";
    ' "$SVU_WAKE_MAC" "$SVU_WAKE_BROADCAST"
    sleep 1
done

echo "SVU wake packet sent."
