#!/usr/bin/env bash
# portmux.sh
# Port multiplexer for managing multiple port redirections via iptables

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CHAIN_NAME="PORTMUX"
CONFIG_FILE="/tmp/portmux.conf"
SERVICES_FILE="/tmp/portmux_services.conf"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Initialize arrays
declare -A ROUTE_DESCRIPTIONS
declare -A SAVED_SERVICES

show_banner() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           ${GREEN}Port Multiplexer Tool${CYAN}               ║${NC}"
    echo -e "${CYAN}║         ${YELLOW}OSCP+ Exam Port Management${CYAN}            ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
    echo
}

show_active_routes() {
    local rules=$(iptables -t nat -L "$CHAIN_NAME" -n 2>/dev/null | grep "DNAT" || true)

    if [[ -n "$rules" ]]; then
        echo -e "${CYAN}Active Redirections:${NC}"
        echo -e "${CYAN}────────────────────${NC}"
        while IFS= read -r line; do
            local dpt=$(echo "$line" | grep -oP 'dpt:\K[0-9]+' || continue)
            local to=$(echo "$line" | grep -oP 'to:\K[0-9.]+:[0-9]+' || continue)
            local port=$(echo "$to" | cut -d: -f2)
            local desc="${ROUTE_DESCRIPTIONS[$dpt]}"

            if [[ -n "$desc" ]]; then
                echo -e "  ${GREEN}:$dpt → :$port${NC} ${YELLOW}($desc)${NC}"
            else
                echo -e "  ${GREEN}:$dpt → :$port${NC}"
            fi
        done <<<"$rules"
        echo
    fi
}

show_menu() {
    show_active_routes
    echo -e "${BLUE}═══════════ Main Menu ═══════════${NC}"
    echo -e "${GREEN}1)${NC} Add port redirection"
    echo -e "${GREEN}2)${NC} Remove port redirection"
    echo -e "${GREEN}3)${NC} List detailed redirections"
    echo -e "${GREEN}4)${NC} Manage saved services"
    echo -e "${GREEN}5)${NC} Clear all redirections"
    echo -e "${GREEN}6)${NC} Show iptables rules"
    echo -e "${GREEN}7)${NC} Test connections"
    echo -e "${GREEN}0)${NC} Exit"
    echo -e "${BLUE}═════════════════════════════════${NC}"
}

init_chain() {
    # Create custom chain if it doesn't exist
    if ! iptables -t nat -L "$CHAIN_NAME" &>/dev/null 2>&1; then
        iptables -t nat -N "$CHAIN_NAME" 2>/dev/null || true
        # Add chain to PREROUTING if not already there
        if ! iptables -t nat -L PREROUTING -n | grep -q "$CHAIN_NAME"; then
            iptables -t nat -A PREROUTING -j "$CHAIN_NAME"
        fi
    fi
}

load_services() {
    if [[ -f "$SERVICES_FILE" ]]; then
        while IFS='=' read -r key value; do
            SAVED_SERVICES["$key"]="$value"
        done <"$SERVICES_FILE"
    fi
}

save_services() {
    >"$SERVICES_FILE"
    for key in "${!SAVED_SERVICES[@]}"; do
        echo "$key=${SAVED_SERVICES[$key]}" >>"$SERVICES_FILE"
    done
}

load_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Load route descriptions
        while IFS='=' read -r key value; do
            if [[ "$key" == DESC_* ]]; then
                port="${key#DESC_}"
                ROUTE_DESCRIPTIONS["$port"]="$value"
            fi
        done <"$CONFIG_FILE"

        # Restore iptables rules
        grep "^-A $CHAIN_NAME" "$CONFIG_FILE" 2>/dev/null | while read -r rule; do
            iptables -t nat $rule 2>/dev/null || true
        done
    fi
}

save_configuration() {
    >"$CONFIG_FILE"

    # Save route descriptions
    for port in "${!ROUTE_DESCRIPTIONS[@]}"; do
        echo "DESC_$port=${ROUTE_DESCRIPTIONS[$port]}" >>"$CONFIG_FILE"
    done

    # Save iptables rules
    iptables-save -t nat | grep "$CHAIN_NAME" >>"$CONFIG_FILE"
}

select_service() {
    local selected_port=""
    local selected_desc=""

    if [[ ${#SAVED_SERVICES[@]} -eq 0 ]]; then
        return 1
    fi

    echo -e "${CYAN}Saved Services:${NC}"
    local i=1
    local -a service_keys=()

    for desc in "${!SAVED_SERVICES[@]}"; do
        port="${SAVED_SERVICES[$desc]}"
        echo -e "  ${GREEN}$i)${NC} $desc - Port $port"
        service_keys+=("$desc")
        ((i++))
    done
    echo -e "  ${GREEN}0)${NC} Manual entry"

    read -p "Select service: " choice

    if [[ "$choice" == "0" || -z "$choice" ]]; then
        return 1
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice > 0 && choice <= ${#service_keys[@]})); then
        selected_desc="${service_keys[$((choice - 1))]}"
        selected_port="${SAVED_SERVICES[$selected_desc]}"
        echo "$selected_port|$selected_desc"
        return 0
    fi

    return 1
}

add_redirection() {
    show_banner
    echo -e "${YELLOW}Add Port Redirection${NC}"
    echo -e "${BLUE}═════════════════════${NC}"
    echo

    read -p "Enter source port (external, e.g., 443): " src_port

    # Validate source port
    if ! [[ "$src_port" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid source port${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    # Check if source port already has a rule
    if iptables -t nat -L "$CHAIN_NAME" -n | grep -q "dpt:$src_port"; then
        echo -e "${YELLOW}Port $src_port already has a redirection${NC}"
        read -p "Overwrite existing rule? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            return
        fi
        # Remove existing rule
        local rule_num=$(iptables -t nat -L "$CHAIN_NAME" -n --line-numbers | grep "dpt:$src_port" | awk '{print $1}' | head -1)
        iptables -t nat -D "$CHAIN_NAME" "$rule_num" 2>/dev/null
    fi

    # Check if we have saved services and show them
    echo
    if [[ ${#SAVED_SERVICES[@]} -gt 0 ]]; then
        echo -e "${CYAN}Select destination service:${NC}"
        local i=1
        local -a service_keys=()

        for desc in "${!SAVED_SERVICES[@]}"; do
            port="${SAVED_SERVICES[$desc]}"
            echo -e "  ${GREEN}$i)${NC} $desc - Port $port"
            service_keys+=("$desc")
            ((i++))
        done
        echo -e "  ${GREEN}0)${NC} Manual entry"

        read -p "Select service: " choice

        if [[ "$choice" == "0" || -z "$choice" ]]; then
            # Manual entry
            read -p "Enter destination port (internal service): " dst_port
            read -p "Enter description (optional, e.g., 'Ligolo'): " description

            # Validate destination port
            if ! [[ "$dst_port" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}Error: Invalid destination port${NC}"
                read -p "Press Enter to continue..."
                return
            fi

            # Ask if user wants to save this service
            if [[ -n "$description" ]]; then
                read -p "Save this service for future use? (Y/n): " save_service
                if [[ ! "$save_service" =~ ^[Nn]$ ]]; then
                    SAVED_SERVICES["$description"]="$dst_port"
                    save_services
                    echo -e "${GREEN}✓ Service saved${NC}"
                fi
            fi
        elif [[ "$choice" =~ ^[0-9]+$ ]] && ((choice > 0 && choice <= ${#service_keys[@]})); then
            # Selected a saved service
            description="${service_keys[$((choice - 1))]}"
            dst_port="${SAVED_SERVICES[$description]}"
        else
            echo -e "${RED}Invalid selection${NC}"
            read -p "Press Enter to continue..."
            return
        fi
    else
        read -p "Enter destination port (internal service): " dst_port
        read -p "Enter description (optional, e.g., 'Ligolo'): " description

        # Validate destination port
        if ! [[ "$dst_port" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Error: Invalid destination port${NC}"
            read -p "Press Enter to continue..."
            return
        fi

        # Ask if user wants to save this service
        if [[ -n "$description" ]]; then
            read -p "Save this service for future use? (Y/n): " save_service
            if [[ ! "$save_service" =~ ^[Nn]$ ]]; then
                SAVED_SERVICES["$description"]="$dst_port"
                save_services
                echo -e "${GREEN}✓ Service saved${NC}"
            fi
        fi
    fi

    read -p "Enter destination IP (default: localhost): " dst_ip
    dst_ip=${dst_ip:-"127.0.0.1"}

    # Add the redirection rule
    init_chain
    iptables -t nat -A "$CHAIN_NAME" -p tcp --dport "$src_port" -j DNAT --to-destination "$dst_ip:$dst_port"

    # Save description
    if [[ -n "$description" ]]; then
        ROUTE_DESCRIPTIONS["$src_port"]="$description"
    fi

    save_configuration

    if [[ -n "$description" ]]; then
        echo -e "${GREEN}✓ Added redirection: :$src_port → :$dst_port ($description)${NC}"
    else
        echo -e "${GREEN}✓ Added redirection: :$src_port → :$dst_port${NC}"
    fi

    read -p "Press Enter to continue..."
}

remove_redirection() {
    show_banner
    echo -e "${YELLOW}Remove Port Redirection${NC}"
    echo -e "${BLUE}═══════════════════════${NC}"

    # List current rules with descriptions
    local rules=$(iptables -t nat -L "$CHAIN_NAME" -n --line-numbers 2>/dev/null | grep -E "^[0-9]" || true)

    if [[ -z "$rules" ]]; then
        echo -e "${YELLOW}No active redirections${NC}"
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "${CYAN}Current redirections:${NC}"
    while IFS= read -r line; do
        num=$(echo "$line" | awk '{print $1}')
        dpt=$(echo "$line" | grep -oP 'dpt:\K[0-9]+' || echo "N/A")
        to=$(echo "$line" | grep -oP 'to:\K[0-9.]+:[0-9]+' || echo "N/A")
        port=$(echo "$to" | cut -d: -f2)
        desc="${ROUTE_DESCRIPTIONS[$dpt]}"

        if [[ -n "$desc" ]]; then
            printf "  ${GREEN}%2s)${NC} :%-5s → :%-5s ${YELLOW}(%s)${NC}\n" "$num" "$dpt" "$port" "$desc"
        else
            printf "  ${GREEN}%2s)${NC} :%-5s → :%-5s\n" "$num" "$dpt" "$port"
        fi
    done <<<"$rules"
    echo

    read -p "Enter rule number to remove (0 to cancel): " rule_num

    if [[ "$rule_num" == "0" ]]; then
        return
    fi

    if [[ "$rule_num" =~ ^[0-9]+$ ]]; then
        # Get port before removing
        local port=$(iptables -t nat -L "$CHAIN_NAME" -n --line-numbers | grep "^$rule_num" | grep -oP 'dpt:\K[0-9]+' || true)

        iptables -t nat -D "$CHAIN_NAME" "$rule_num" 2>/dev/null &&
            echo -e "${GREEN}✓ Rule removed${NC}" ||
            echo -e "${RED}Error: Failed to remove rule${NC}"

        # Remove description
        if [[ -n "$port" ]]; then
            unset ROUTE_DESCRIPTIONS["$port"]
        fi

        save_configuration
    else
        echo -e "${RED}Error: Invalid rule number${NC}"
    fi

    read -p "Press Enter to continue..."
}

list_redirections() {
    show_banner
    echo -e "${YELLOW}Detailed Port Redirections${NC}"
    echo -e "${BLUE}══════════════════════════${NC}"

    local rules=$(iptables -t nat -L "$CHAIN_NAME" -n -v --line-numbers 2>/dev/null | grep -E "^[0-9]" || true)

    if [[ -z "$rules" ]]; then
        echo -e "${YELLOW}No active redirections${NC}"
    else
        echo -e "${CYAN}Num  Proto  Pkts  Bytes  Source Port  →  Destination       Description${NC}"
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────────────${NC}"
        while IFS= read -r line; do
            num=$(echo "$line" | awk '{print $1}')
            proto=$(echo "$line" | awk '{print $2}')
            pkts=$(echo "$line" | awk '{print $3}')
            bytes=$(echo "$line" | awk '{print $4}')
            dpt=$(echo "$line" | grep -oP 'dpt:\K[0-9]+' || echo "N/A")
            to=$(echo "$line" | grep -oP 'to:\K[0-9.]+:[0-9]+' || echo "N/A")
            desc="${ROUTE_DESCRIPTIONS[$dpt]}"

            printf "%-4s %-6s %-5s %-6s :%-11s →  %-16s %s\n" \
                "$num" "$proto" "$pkts" "$bytes" "$dpt" "$to" "$desc"
        done <<<"$rules"
    fi

    echo
    read -p "Press Enter to continue..."
}

manage_services() {
    while true; do
        show_banner
        echo -e "${YELLOW}Manage Saved Services${NC}"
        echo -e "${BLUE}═════════════════════${NC}"

        if [[ ${#SAVED_SERVICES[@]} -gt 0 ]]; then
            echo -e "${CYAN}Current saved services:${NC}"
            for desc in "${!SAVED_SERVICES[@]}"; do
                port="${SAVED_SERVICES[$desc]}"
                echo -e "  • ${GREEN}$desc${NC} - Port ${YELLOW}$port${NC}"
            done
            echo
        else
            echo -e "${YELLOW}No saved services${NC}"
            echo
        fi

        echo -e "${GREEN}1)${NC} Add service"
        echo -e "${GREEN}2)${NC} Remove service"
        echo -e "${GREEN}3)${NC} Back to main menu"
        echo

        read -p "Select option: " opt

        case $opt in
        1)
            read -p "Enter service description (e.g., 'Ligolo'): " desc
            read -p "Enter service port: " port
            if [[ "$port" =~ ^[0-9]+$ ]] && [[ -n "$desc" ]]; then
                SAVED_SERVICES["$desc"]="$port"
                save_services
                echo -e "${GREEN}✓ Service saved${NC}"
            else
                echo -e "${RED}Invalid input${NC}"
            fi
            read -p "Press Enter to continue..."
            ;;
        2)
            if [[ ${#SAVED_SERVICES[@]} -eq 0 ]]; then
                echo -e "${YELLOW}No services to remove${NC}"
            else
                echo -e "${CYAN}Select service to remove:${NC}"
                local i=1
                local -a service_keys=()
                for desc in "${!SAVED_SERVICES[@]}"; do
                    echo -e "  ${GREEN}$i)${NC} $desc"
                    service_keys+=("$desc")
                    ((i++))
                done
                read -p "Enter number (0 to cancel): " choice
                if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice > 0 && choice <= ${#service_keys[@]})); then
                    local key="${service_keys[$((choice - 1))]}"
                    unset SAVED_SERVICES["$key"]
                    save_services
                    echo -e "${GREEN}✓ Service removed${NC}"
                fi
            fi
            read -p "Press Enter to continue..."
            ;;
        3)
            break
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            read -p "Press Enter to continue..."
            ;;
        esac
    done
}

clear_all_redirections() {
    (
        # Run in subshell to prevent exit on error
        # Remove chain from PREROUTING
        iptables -t nat -D PREROUTING -j "$CHAIN_NAME" 2>/dev/null || true

        # Flush and delete chain
        iptables -t nat -F "$CHAIN_NAME" 2>/dev/null || true
        iptables -t nat -X "$CHAIN_NAME" 2>/dev/null || true
    )

    # Clear descriptions
    ROUTE_DESCRIPTIONS=()
    
    # Save empty configuration
    >"$CONFIG_FILE"
    
    echo -e "${GREEN}✓ All redirections cleared${NC}"
    
    # Re-initialize the chain for future use
    init_chain
}

show_iptables_rules() {
    show_banner
    echo -e "${YELLOW}Current IPTables NAT Rules${NC}"
    echo -e "${BLUE}═══════════════════════════${NC}"

    echo -e "${CYAN}PREROUTING chain:${NC}"
    iptables -t nat -L PREROUTING -n -v --line-numbers | head -20

    echo
    echo -e "${CYAN}$CHAIN_NAME chain:${NC}"
    iptables -t nat -L "$CHAIN_NAME" -n -v --line-numbers 2>/dev/null || echo "Chain not initialized"

    echo
    read -p "Press Enter to continue..."
}

test_connections() {
    show_banner
    echo -e "${YELLOW}Test Connections${NC}"
    echo -e "${BLUE}════════════════${NC}"

    echo -e "${CYAN}Testing redirected ports...${NC}"
    echo

    # Get all DNAT rules
    local rules=$(iptables -t nat -L "$CHAIN_NAME" -n 2>/dev/null | grep "DNAT" || true)

    if [[ -z "$rules" ]]; then
        echo -e "${YELLOW}No active redirections to test${NC}"
    else
        while IFS= read -r line; do
            local dpt=$(echo "$line" | grep -oP 'dpt:\K[0-9]+' || continue)
            local to=$(echo "$line" | grep -oP 'to:\K[0-9.]+:[0-9]+' || continue)
            local ip=$(echo "$to" | cut -d: -f1)
            local port=$(echo "$to" | cut -d: -f2)
            local desc="${ROUTE_DESCRIPTIONS[$dpt]}"

            if [[ -n "$desc" ]]; then
                echo -n "Testing :$dpt → :$port ($desc): "
            else
                echo -n "Testing :$dpt → :$port: "
            fi

            # Test with timeout
            if timeout 2 bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null; then
                echo -e "${GREEN}✓ Connected${NC}"
            else
                echo -e "${RED}✗ Failed${NC}"
            fi
        done <<<"$rules"
    fi

    echo
    read -p "Press Enter to continue..."
}

cleanup() {
    echo
    save_configuration
    echo -e "${YELLOW}Configuration saved.${NC}"
    echo -e "${YELLOW}Do you want to clear all redirections before exiting?${NC}"
    read -p "(y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        clear_all_redirections
    fi

    echo -e "${GREEN}Goodbye!${NC}"
    exit 0
}

# Trap Ctrl+C
trap cleanup INT

# Initialize
init_chain
load_services
load_configuration

# Main loop
while true; do
    show_banner
    show_menu

    read -p "Select option: " choice

    case $choice in
    1) add_redirection ;;
    2) remove_redirection ;;
    3) list_redirections ;;
    4) manage_services ;;
    5)
        show_banner
        echo -e "${YELLOW}Clear all redirections?${NC}"
        read -p "(y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            clear_all_redirections
            read -p "Press Enter to continue..."
        else
            read -p "Press Enter to continue..."
        fi
        ;;
    6) show_iptables_rules ;;
    7) test_connections ;;
    0) cleanup ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        read -p "Press Enter to continue..."
        ;;
    esac
done
