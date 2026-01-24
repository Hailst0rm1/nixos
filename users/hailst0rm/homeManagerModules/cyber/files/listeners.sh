#!/usr/bin/env bash

# Colors
GREEN="\033[1;32m"
BLUE="\033[1;34m"
NC="\033[0m" # No Color

# Function to run a ghostty command with logging
run_ghostty() {
  local message="$1"
  shift
  local cmd="$*"
  
  # Run with explicit PATH export to ensure commands are found
  ghostty -e bash -c "
    echo -e '${GREEN}[+] $message${NC}'
    echo -e '${BLUE}[+] Command:${NC} $cmd'
    export PATH=\"${PATH}\"
    $cmd 
    echo ''
    echo -e '${GREEN}Press Enter to close this window...${NC}'
    read
  " &>/dev/null &
}

# Prepare Ligolo-MP agent
# sudo mkdir -p /root/.ligolo-mp-server/assets/go/bin
# sudo ln -sf "$(which go)" /root/.ligolo-mp-server/assets/go/bin/go
# sudo ln -sf "$(which gofmt)" /root/.ligolo-mp-server/assets/go/bin/gofmt 
# sudo ln -sf "$(which garble)" /root/.ligolo-mp-server/assets/go/bin/garble 

# Start Ligolo-MP server
run_ghostty "Starting Ligolo-MP server..." "ligolo-mp --agent-addr 0.0.0.0:8000"
# run_ghostty "Starting Ligolo-MP server..." "sudo ligolo-mp --agent-addr 0.0.0.0:8000"
sleep 1

# Start caido
caido &>/dev/null &

# Start BloodHound
BloodHound &>/dev/null &

# Start Sliver C2 server
PAYLOAD_DIR="/home/hailst0rm/cyber/postex-tools/payloads"
mkdir -p "$PAYLOAD_DIR"
cd "$PAYLOAD_DIR"
run_ghostty "Starting Sliver C2 server..." "sliver-server"
sleep 1

# Start Metasploit listeners
# run_ghostty "Starting Metasploit Reverse Shell listener... (Windows, port 8000)" \
#   "sudo msfconsole -q --resource ~/cyber/metasploit/win-revtcp-listener.rc"

# run_ghostty "Starting Metasploit Reverse Shell listener... (Linux, port 8001)" \
#   "sudo msfconsole -q --resource ~/cyber/metasploit/lin-revtcp-listener.rc"
# sleep 1

# run_ghostty "Starting Penlope Reverse Shell listener... (port 4444)" \
#   "sudo penelope.py -a 4444"

# Start HTTP exfil server
EXFIL_DIR="/home/hailst0rm/Documents/Exfiltration"
mkdir -p "$EXFIL_DIR"
run_ghostty "Starting HTTP Exfiltration server... ($EXFIL_DIR)" \
  "httpuploadexfil :8080 $EXFIL_DIR"

# Start Python HTTP server
HTTP_DIR="/home/hailst0rm/cyber/postex-tools"
HTTP_CMD="python -m http.server 80 -d $HTTP_DIR"
echo -e "${GREEN}[+] Starting Python HTTP server... (~/cyber/postex-tools)${NC}"
echo -e "${BLUE}[+] Command run:${NC} $HTTP_CMD"
$HTTP_CMD
sleep 1
