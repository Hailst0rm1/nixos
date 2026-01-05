#!/usr/bin/env bash

set -euo pipefail

# Check if ovpn file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <ovpn-file>"
    exit 1
fi

OVPN_FILE="$1"

if [ ! -f "$OVPN_FILE" ]; then
    echo "Error: OVPN file '$OVPN_FILE' not found"
    exit 1
fi

# Variables to store parsed values
DNS_IP=""
INTERFACE=""

echo "Starting AWS CVPN client..."

# Run the AWS CVPN client and parse output
sudo nix run github:sirn/aws-cvpn-client "$OVPN_FILE" 2>&1 | while IFS= read -r line; do
    # Print the line for visibility
    echo "$line"

    # Parse DNS IP from PUSH_REPLY message
    if [[ "$line" =~ dhcp-option\ DNS\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
        DNS_IP="${BASH_REMATCH[1]}"
        echo "[WRAPPER] Detected DNS IP: $DNS_IP"
    fi

    # Parse interface name from net_iface_up message
    if [[ "$line" =~ net_iface_up:\ set\ ([a-z0-9]+)\ up ]]; then
        INTERFACE="${BASH_REMATCH[1]}"
        echo "[WRAPPER] Detected interface: $INTERFACE"

        # If we have both values, configure DNS
        if [ -n "$DNS_IP" ] && [ -n "$INTERFACE" ]; then
            echo "[WRAPPER] Configuring DNS: sudo resolvectl dns $INTERFACE $DNS_IP"
            sudo resolvectl dns "$INTERFACE" "$DNS_IP"
            echo "[WRAPPER] DNS configured successfully"
        fi
    fi
done
