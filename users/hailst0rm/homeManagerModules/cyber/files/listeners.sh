#!/usr/bin/env bash

GREEN="\033[1;32m"
NC="\033[0m" # No Color

# Start Python HTTP server
ghostty -e "echo -e '${GREEN}[+] Starting Python HTTP server... (~/cyber/postex-tools)${NC}'; sudo python -m http.server 80 -d ~/cyber/postex-tools" &>/dev/null &

# Start Ligolo-MP agent
ghostty -e "echo -e '${GREEN}[+] Starting Ligolo-MP server...${NC}'; sudo ligolo-mp --agent-addr 0.0.0.0:8000" &>/dev/null &

# Start HTTP exfil server
ghostty -e "echo -e '${GREEN}[+] Starting HTTP Exfiltration server... (~/Documents/Exfiltration)${NC}'; sudo httpuploadexfil :8080 ~/Documents/Exfiltration" &>/dev/null &

# Start Metasploit listeners
ghostty -e "echo -e '${GREEN}[+] Starting Metasploit Reverse Shell listener... (Windows, port 443)${NC}'; sudo msfconsole --resource ~/cyber/metasploit/win-revtcp-listener.rc" &>/dev/null &
ghostty -e "echo -e '${GREEN}[+] Starting Metasploit Reverse Shell listener... (Linux, port 8001)${NC}'; sudo msfconsole --resource ~/cyber/metasploit/lin-revtcp-listener.rc" &>/dev/null &
