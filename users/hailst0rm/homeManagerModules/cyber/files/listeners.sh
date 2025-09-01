#!/usr/bin/env bash

GREEN="\033[1;32m"
NC="\033[0m" # No Color

# Start Ligolo-MP agent
sudo mkdir -p /root/.ligolo-mp-server/assets/go/bin
sudo ln -sf $(which go) /root/.ligolo-mp-server/assets/go/bin/go
sudo ln -sf $(which gofmt) /root/.ligolo-mp-server/assets/go/bin/gofmt 
sudo ln -sf $(which garble) /root/.ligolo-mp-server/assets/go/bin/garble 
ghostty -e "echo -e '${GREEN}[+] Starting Ligolo-MP server...${NC}'; sudo ligolo-mp --agent-addr 0.0.0.0:8000" &>/dev/null &
sleep 1

# Start caido
caido &>/dev/null &

# Start BloodHound
BloodHound &>/dev/null &

# Start Metasploit listeners
ghostty -e "echo -e '${GREEN}[+] Starting Metasploit Reverse Shell listener... (Windows, port 443)${NC}'; sudo msfconsole --resource ~/cyber/metasploit/win-revtcp-listener.rc" &>/dev/null &
ghostty -e "echo -e '${GREEN}[+] Starting Metasploit Reverse Shell listener... (Linux, port 8001)${NC}'; sudo msfconsole --resource ~/cyber/metasploit/lin-revtcp-listener.rc" &>/dev/null &
sleep 1

# Start Python HTTP server
ghostty -e "echo -e '${GREEN}[+] Starting Python HTTP server... (~/cyber/postex-tools)${NC}'; sudo python -m http.server 80 -d ~/cyber/postex-tools" &>/dev/null &
sleep 1

# Start HTTP exfil server
EXFIL_DIR="/home/hailst0rm/Documents/Exfiltration"
mkdir -p $EXFIL_DIR
ghostty -e "echo -e '${GREEN}[+] Starting HTTP Exfiltration server... ($(echo $EXFIL_DIR))${NC}'; sudo httpuploadexfil :8080 $EXFIL_DIR" &>/dev/null &

