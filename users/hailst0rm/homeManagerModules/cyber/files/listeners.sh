#!/usr/bin/env bash

# Port Configuration
LIGOLO_PORT=8000
SLIVER_MTLS_PORT=8888
SLIVER_HTTP_PORT=80
SLIVER_HTTPS_PORT=443
EXFIL_HTTP_PORT=8080
PYTHON_HTTP_PORT=80

# Colors
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

# Help message
show_help() {
  echo -e "${GREEN}=== Listener Port Configuration ===${NC}"
  echo -e "${BLUE}Ligolo-MP Agent:${NC}       0.0.0.0:${LIGOLO_PORT}"
  echo -e "${BLUE}Sliver MTLS:${NC}           0.0.0.0:${SLIVER_MTLS_PORT}"
  echo -e "${BLUE}Sliver HTTP:${NC}           0.0.0.0:${SLIVER_HTTP_PORT}"
  echo -e "${BLUE}Sliver HTTPS:${NC}          0.0.0.0:${SLIVER_HTTPS_PORT}"
  echo -e "${BLUE}HTTP Exfil Server:${NC}     0.0.0.0:${EXFIL_HTTP_PORT}"
  echo -e "${BLUE}Python HTTP Server:${NC}    0.0.0.0:${PYTHON_HTTP_PORT}"
  echo -e "${GREEN}===================================${NC}"
  echo ""
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
  exit 0
fi

# Display ports on startup
show_help

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

# Start caido
caido &>/dev/null &

# Start BloodHound
BloodHound &>/dev/null &

# Start Paygen server
paygen &>/dev/null &

# Start Ligolo-MP server
run_ghostty "Starting Ligolo-MP server (port ${LIGOLO_PORT})..." "ligolo-mp --agent-addr 0.0.0.0:${LIGOLO_PORT}"
sleep 1

# Start Sliver C2 server
PAYLOAD_DIR="/home/hailst0rm/cyber/postex-tools/payloads"
mkdir -p "$PAYLOAD_DIR"
cd "$PAYLOAD_DIR"
run_ghostty "Starting Sliver C2 server..." "sliver-server"
sleep 1

# Start HTTP exfil server
EXFIL_DIR="/home/hailst0rm/Documents/Exfiltration"
mkdir -p "$EXFIL_DIR"
run_ghostty "Starting HTTP Exfiltration server (port ${EXFIL_HTTP_PORT})... ($EXFIL_DIR)" \
  "httpuploadexfil :${EXFIL_HTTP_PORT} $EXFIL_DIR"

# Start Python HTTP server
HTTP_DIR="/home/hailst0rm/cyber/postex-tools"
HTTP_CMD="python -m http.server ${PYTHON_HTTP_PORT} -d $HTTP_DIR"
echo -e "${GREEN}[+] Starting Python HTTP server (port ${PYTHON_HTTP_PORT})... (~/cyber/postex-tools)${NC}"
echo -e "${BLUE}[+] Command run:${NC} $HTTP_CMD"
$HTTP_CMD
sleep 1

# ===== Archive =====

# Start Metasploit listeners
# run_ghostty "Starting Metasploit Reverse Shell listener... (Windows, port 8000)" \
#   "sudo msfconsole -q --resource ~/cyber/metasploit/win-revtcp-listener.rc"

# run_ghostty "Starting Metasploit Reverse Shell listener... (Linux, port 8001)" \
#   "sudo msfconsole -q --resource ~/cyber/metasploit/lin-revtcp-listener.rc"
# sleep 1

# run_ghostty "Starting Penlope Reverse Shell listener... (port 4444)" \
#   "sudo penelope.py -a 4444"
