#!/usr/bin/env bash  # Use bash as default; compatible with zsh via sourcing

ENV_FILE="$HOME/.config/.my_vars.env"

# ANSI colors (works in Bash and Zsh)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Make sure the script is being sourced
sourced=0
# Bash check
if [ -n "$BASH_VERSION" ]; then
    [[ "${BASH_SOURCE[0]}" != "$0" ]] && sourced=1
# Zsh check
elif [ -n "$ZSH_VERSION" ]; then
    case $ZSH_EVAL_CONTEXT in *:file) sourced=0;; *) sourced=1;; esac
fi

if [[ $sourced -eq 0 ]]; then
    echo -e "${RED}[!]${NC} Error: This script must be sourced, not executed." >&2
    return 1 2>/dev/null || exit 1
fi

# Load existing values
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

# Declare associative array
if [ -n "$BASH_VERSION" ]; then
    declare -A vars
else
    typeset -A vars
fi

vars=(
    [DC_IP]="$DC_IP"
    [DOMAIN]="$DOMAIN"
    [USER]="$USER"
    [PASSWORD]="$PASSWORD"
    [DC_HOST]="$DC_HOST"
    [NT_HASH]="$NT_HASH"
)

ordered_keys=(DC_IP DOMAIN USER PASSWORD DC_HOST NT_HASH)

# Print variables
print_vars() {
    echo -e "\n${BOLD}${CYAN}Variables:${NC}\n"
    local i=1 key
    for key in "${ordered_keys[@]}"; do
        printf " %2d) %-10s : %s\n" "$i" "$key" "${vars[$key]}"
        ((i++))
    done
    echo ""
}

# Convert index → key
get_key_by_index() {
    echo "${ordered_keys[$1-1]}"
}

# Parse flags
while [ $# -gt 0 ]; do
    case "$1" in
        -s|--source)
            if [ -f "$ENV_FILE" ]; then
                source "$ENV_FILE"
                echo -e "${GREEN}Sourced $ENV_FILE${NC}"
            else
                echo -e "${RED}Env file not found${NC}"
            fi
            print_vars
            return 0
            ;;
        -l|--list)
            print_vars
            return 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            return 1
            ;;
        *)
            break
            ;;
    esac
done

# Interactive menu
while true; do
    print_vars

    # Prompt safely for both Bash and Zsh
    if [ -n "$BASH_VERSION" ]; then
        read -rp "${YELLOW}Selection (number or 'exit'): ${NC}" sel
    else
        read "sel?${YELLOW}Selection (number or 'exit'): ${NC}"
    fi

    [[ "$sel" == "exit" ]] && break

    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#ordered_keys[@]} )); then
        key=$(get_key_by_index "$sel")

        if [ -n "$BASH_VERSION" ]; then
            read -rp "${YELLOW}Enter value for $key: ${NC}" val
        else
            read "val?${YELLOW}Enter value for $key: ${NC}"
        fi

        export "$key=$val"
        vars[$key]="$val"

        # Save to file
        grep -v "^$key=" "$ENV_FILE" 2>/dev/null > "$ENV_FILE.tmp"
        echo "$key='$val'" >> "$ENV_FILE.tmp"
        mv "$ENV_FILE.tmp" "$ENV_FILE"

        echo -e "${GREEN}$key set.${NC}\n"
    else
        echo -e "${RED}Invalid selection${NC}\n"
    fi
done

echo -e "${CYAN}Variables saved to $ENV_FILE. Source it in future shells to load.${NC}"
