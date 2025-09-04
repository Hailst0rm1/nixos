#!/usr/bin/env zsh

ENV_FILE="$HOME/.config/.my_vars.env"

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

# Load existing values
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# Associative array
typeset -A vars=(
    OUTDIR "$OUTDIR"
    C2 "$C2"
    TARGET "$TARGET"
    TARGETS "$TARGETS"
    CIDR "$CIDR"
    DC "$DC"
    DOMAIN "$DOMAIN"
    USER "$USER"
    PASSWORD "$PASSWORD"
    NT_HASH "$NT_HASH"
    AES_KEY "$AES_KEY"
)

# Ordered keys
ordered_keys=( OUTDIR C2 TARGET TARGETS CIDR DC DOMAIN USER PASSWORD NT_HASH AES_KEY)

print_vars() {
    print -P "\n${BOLD}${CYAN}Variables:${NC}\n"
    local i=1
    for key in $ordered_keys; do
        printf " %2d) %-10s : %s\n" $i "$key" "${vars[$key]}"
        (( i++ ))
    done
    print ""
}

get_key_by_index() {
    echo "${ordered_keys[$1]}"
}

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--source)
            [[ -f "$ENV_FILE" ]] && source "$ENV_FILE" && print -P "${GREEN}Sourced $ENV_FILE${NC}" || print -P "${RED}Env file not found${NC}"
            print_vars
            return 0
            ;;
        -l|--list)
            [[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
            print_vars
            return 0
            ;;
        -d|--delete-all)
            # Unset all vars and clear file
            set +o nomatch 2>/dev/null
            for key in $ordered_keys; do
                unset "$key"
                unset vars[$key]
            done
            set -o nomatch 2>/dev/null
            "" > "$ENV_FILE" 2>/dev/null
            print -P "${GREEN}All variables deleted and $ENV_FILE cleared.${NC}"
            return 0
            ;;
        -*)
            print -P "${RED}Unknown option: $1${NC}"
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
    read -r "sel?${YELLOW}Selection (number or 'exit'): ${NC}"
    [[ "$sel" == "exit" ]] && break

    # zsh-safe numeric check
    if [[ "$sel" = [1-9]* ]] && (( sel >= 1 && sel <= ${#ordered_keys[@]} )); then
        key=$(get_key_by_index $sel)
        read -r "val?${YELLOW}Enter value for $key: ${NC}"

        export "$key=$val"
        vars[$key]="$val"

        # Persist to file
        grep -v "^$key=" "$ENV_FILE" 2>/dev/null > "$ENV_FILE.tmp"
        echo "$key='$val'" >> "$ENV_FILE.tmp"
        mv "$ENV_FILE.tmp" "$ENV_FILE"

        print -P "${GREEN}$key set.${NC}\n"
    else
        print -P "${RED}Invalid selection${NC}\n"
    fi
done

print -P "${CYAN}Variables saved to $ENV_FILE. Source it in future shells to load.${NC}"
