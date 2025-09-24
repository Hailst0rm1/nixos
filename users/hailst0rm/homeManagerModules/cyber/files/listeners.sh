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
  ghostty -e "echo -e '${GREEN}[+] $message${NC}'; echo -e '${BLUE}[+] Command run:${NC} $cmd'; $cmd" &>/dev/null &
}

# Prepare Ligolo-MP agent
sudo mkdir -p /root/.ligolo-mp-server/assets/go/bin
sudo ln -sf "$(which go)" /root/.ligolo-mp-server/assets/go/bin/go
sudo ln -sf "$(which gofmt)" /root/.ligolo-mp-server/assets/go/bin/gofmt 
sudo ln -sf "$(which garble)" /root/.ligolo-mp-server/assets/go/bin/garble 

# Start Ligolo-MP server
run_ghostty "Starting Ligolo-MP server..." "sudo ligolo-mp --agent-addr 0.0.0.0:443"
sleep 1

# Start caido
caido &>/dev/null &

# Start BloodHound
BloodHound &>/dev/null &

# Start Metasploit listeners
run_ghostty "Starting Metasploit Reverse Shell listener... (Windows, port 8000)" \
  "sudo msfconsole -q --resource ~/cyber/metasploit/win-revtcp-listener.rc"

run_ghostty "Starting Metasploit Reverse Shell listener... (Linux, port 8001)" \
  "sudo msfconsole -q --resource ~/cyber/metasploit/lin-revtcp-listener.rc"
sleep 1

# Start HTTP exfil server
EXFIL_DIR="/home/hailst0rm/Documents/Exfiltration"
mkdir -p "$EXFIL_DIR"
run_ghostty "Starting HTTP Exfiltration server... ($EXFIL_DIR)" \
  "sudo httpuploadexfil :8080 $EXFIL_DIR"

# Start Python HTTP server
HTTP_DIR="/home/hailst0rm/cyber/postex-tools"
HTTP_CMD="sudo python -m http.server 80 -d $HTTP_DIR"
echo -e "${GREEN}[+] Starting Python HTTP server... (~/cyber/postex-tools)${NC}"
echo -e "${BLUE}[+] Command run:${NC} $HTTP_CMD"
$HTTP_CMD
sleep 1
