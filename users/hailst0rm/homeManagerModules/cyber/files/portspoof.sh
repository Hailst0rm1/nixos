#!/usr/bin/env bash
# portspoof.sh
# Redirects all TCP ports to port 80 for firewall testing

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default target port
DEFAULT_TARGET_PORT=80
CHAIN_NAME="FIREWALL_TEST_REDIRECT"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

show_status() {
    echo -e "\n${YELLOW}Current iptables NAT rules:${NC}"
    iptables -t nat -L PREROUTING -n -v --line-numbers | grep -E "(Chain|$CHAIN_NAME|$TARGET_PORT)" || echo "No redirect rules found"

    echo -e "\n${YELLOW}Listening services on port $TARGET_PORT:${NC}"
    ss -tlnp | grep ":$TARGET_PORT " || echo "Nothing listening on port $TARGET_PORT"

    echo -e "\n${YELLOW}Currently listening ports:${NC}"
    local ports=$(ss -tlnp | awk 'NR>1 {split($4,a,":"); print a[length(a)]}' | sort -un | tr '\n' ',' | sed 's/,$//')
    echo "$ports"
}

get_listening_ports() {
    # Get all currently listening TCP ports, sorted and unique
    ss -tlnp | awk 'NR>1 {split($4,a,":"); print a[length(a)]}' | sort -un
}

enable_redirect() {
    # Check if rules already exist
    if iptables -t nat -L PREROUTING -n | grep -q "$CHAIN_NAME"; then
        echo -e "${YELLOW}Redirect rules already exist!${NC}"
        show_status
        return
    fi

    # Check if port $TARGET_PORT has a listener
    if ! ss -tlnp | grep -q ":$TARGET_PORT "; then
        echo -e "${RED}Warning: No service is listening on port $TARGET_PORT${NC}"
        echo -e "${YELLOW}You should start a listener first:${NC}"
        echo "  sudo $0 listen $TARGET_PORT"
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    echo -e "${GREEN}Enabling port redirection...${NC}"

    # Auto-detect listening ports
    local listening_ports=$(get_listening_ports | tr '\n' ',' | sed 's/,$//')

    # Create custom chain for easy management
    iptables -t nat -N $CHAIN_NAME 2>/dev/null || true

    # Always exclude SSH (22) and the target port itself
    local always_exclude="22,$TARGET_PORT"

    # Combine and deduplicate ports
    local all_exclude="${always_exclude}${listening_ports:+,$listening_ports}"

    # Remove duplicates
    all_exclude=$(echo "$all_exclude" | tr ',' '\n' | sort -un | tr '\n' ',' | sed 's/,$//')

    echo -e "${YELLOW}Excluding ports: $all_exclude${NC}"

    # Add exclusion rules for each port
    IFS=',' read -ra PORTS <<<"$all_exclude"
    for port in "${PORTS[@]}"; do
        port=$(echo "$port" | xargs)
        if [[ "$port" =~ ^[0-9]+$ ]]; then
            iptables -t nat -A $CHAIN_NAME -p tcp --dport "$port" -j RETURN
        fi
    done

    # Redirect everything else to target port
    iptables -t nat -A $CHAIN_NAME -p tcp -j REDIRECT --to-port $TARGET_PORT

    # Insert the chain into PREROUTING
    iptables -t nat -A PREROUTING -j $CHAIN_NAME

    echo -e "${GREEN}✓ Redirect enabled successfully${NC}"
    echo -e "All TCP ports (except excluded) now redirect to port $TARGET_PORT"
}

disable_redirect() {
    echo -e "${YELLOW}Disabling port redirection...${NC}"

    # Remove the chain from PREROUTING
    iptables -t nat -D PREROUTING -j $CHAIN_NAME 2>/dev/null || true

    # Flush and delete the custom chain
    iptables -t nat -F $CHAIN_NAME 2>/dev/null || true
    iptables -t nat -X $CHAIN_NAME 2>/dev/null || true

    echo -e "${GREEN}✓ Redirect disabled successfully${NC}"
}

start_listener() {
    echo -e "${GREEN}Starting HTTP listener on port $TARGET_PORT...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}\n"

    # Check for socat first (best option)
    if command -v socat &>/dev/null; then
        echo "Using socat..."
        socat -v TCP-LISTEN:$TARGET_PORT,fork,reuseaddr SYSTEM:'echo "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nPort '$TARGET_PORT' responding - Firewall test active"'
    # Check for ncat (nmap's netcat)
    elif command -v ncat &>/dev/null; then
        echo "Using ncat..."
        ncat -l -k $TARGET_PORT -c 'echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nPort '$TARGET_PORT' responding"'
    # GNU netcat
    elif command -v nc &>/dev/null; then
        echo "Using netcat loop..."
        while true; do
            echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nPort $TARGET_PORT responding - Firewall test active" | nc -l $TARGET_PORT
        done
    else
        echo -e "${RED}Error: No suitable listener found (nc, ncat, or socat required)${NC}"
        exit 1
    fi
}

show_help() {
    cat <<EOF
${GREEN}Firewall Testing Port Redirect Script${NC}

Usage: $0 [OPTION] [PORT]

Options:
  enable [PORT]   Auto-detect listening ports and enable redirection to PORT (default: $DEFAULT_TARGET_PORT)
  disable         Disable port redirection
  status [PORT]   Show current redirection status for PORT (default: $DEFAULT_TARGET_PORT)
  listen [PORT]   Start a simple listener on PORT (default: $DEFAULT_TARGET_PORT)
  help            Show this help message

Examples:
  $0 listen 8080        # Start redirect target listener on port 8080
  $0 enable 8080        # Enable with auto-detection, redirect to port 8080
  $0 status 8080        # Check current rules for port 8080
  $0 disable            # Disable redirection

Notes:
  - Automatically excludes all currently listening ports
  - SSH (port 22) and target port are always excluded
  - Requires root privileges

Workflow:
  1. Start your services (e.g., ligolo on port 8000)
  2. sudo $0 listen 8080              # Start redirect target listener
  3. sudo $0 enable 8080              # Enable with auto-exclusion to port 8080
  4. Run your port scanner
  5. sudo $0 disable                  # Clean up

EOF
}

# Parse arguments
ACTION="${1:-help}"
PORT_ARG="${2:-}"
if [[ "$ACTION" =~ ^(enable|listen|status)$ ]]; then
    if [[ -n "$PORT_ARG" && "$PORT_ARG" =~ ^[0-9]+$ ]]; then
        TARGET_PORT="$PORT_ARG"
    else
        TARGET_PORT="$DEFAULT_TARGET_PORT"
    fi
else
    TARGET_PORT="$DEFAULT_TARGET_PORT"
fi

# Main logic
case "$ACTION" in
enable)
    enable_redirect
    show_status
    ;;
disable)
    disable_redirect
    ;;
status)
    show_status
    ;;
listen)
    start_listener
    ;;
help | --help | -h)
    show_help
    ;;
*)
    echo -e "${RED}Unknown option: $ACTION${NC}"
    show_help
    exit 1
    ;;
esac
