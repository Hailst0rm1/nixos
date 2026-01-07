#!/usr/bin/env zsh

# ═══════════════════════════════════════════════════════════════════
# Requirements and Error Checking
# ═══════════════════════════════════════════════════════════════════

# Check if running in ZSH (required for associative arrays and other features)
if [[ -z "$ZSH_VERSION" ]]; then
    echo "ERROR: This script requires ZSH shell"
    echo "Current shell: ${BASH_VERSION:+bash }${BASH_VERSION:-unknown}"
    echo ""
    echo "Please run with: source var.sh (from within zsh)"
    echo "Or switch to zsh first: exec zsh"
    return 1 2>/dev/null
fi

# Check ZSH version (need at least 5.0 for associative arrays)
if [[ "${ZSH_VERSION%%.*}" -lt 5 ]]; then
    echo "ERROR: ZSH version 5.0 or higher required"
    echo "Current version: $ZSH_VERSION"
    return 1 2>/dev/null
fi

# Check for required commands
check_requirements() {
    local missing_cmds=()
    local required_cmds=(grep mv rm mkdir printf)
    
    for cmd in $required_cmds; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_cmds+=("$cmd")
        fi
    done
    
    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        echo "ERROR: Missing required commands: ${missing_cmds[*]}"
        echo "Please install the missing commands and try again"
        return 1
    fi
    
    return 0
}

# Run requirements check
if ! check_requirements; then
    return 1 2>/dev/null
fi

# Check HOME variable
if [[ -z "$HOME" ]]; then
    echo "ERROR: HOME environment variable is not set"
    return 1 2>/dev/null
fi

# Create config directory if it doesn't exist
CONFIG_DIR="$HOME/.config"
if [[ ! -d "$CONFIG_DIR" ]]; then
    if ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then
        echo "ERROR: Cannot create config directory: $CONFIG_DIR"
        echo "Please check permissions"
        return 1 2>/dev/null
    fi
fi

ENV_FILE="$CONFIG_DIR/.my_vars.env"

# Check file permissions
if [[ -f "$ENV_FILE" ]]; then
    if [[ ! -r "$ENV_FILE" ]]; then
        echo "ERROR: Cannot read environment file: $ENV_FILE"
        echo "Please check file permissions"
        return 1 2>/dev/null
    fi
    if [[ ! -w "$ENV_FILE" ]]; then
        echo "WARNING: Environment file is read-only: $ENV_FILE"
        echo "You will not be able to save changes"
        echo -n "Continue anyway? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            return 1 2>/dev/null
        fi
    fi
else
    # Try to create the file to test write permissions
    if ! touch "$ENV_FILE" 2>/dev/null; then
        echo "ERROR: Cannot create environment file: $ENV_FILE"
        echo "Please check directory permissions"
        return 1 2>/dev/null
    fi
fi

# Check terminal capabilities for colors (non-fatal)
if [[ ! -t 1 ]] || [[ "${TERM:-dumb}" == "dumb" ]]; then
    echo "WARNING: Terminal does not support colors"
    echo "Output may not display correctly"
fi

# ═══════════════════════════════════════════════════════════════════
# Main Script Start
# ═══════════════════════════════════════════════════════════════════

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BLUE=$'\033[1;34m'
PURPLE=$'\033[0;35m'
ORANGE=$'\033[0;33m'
BOLD=$'\033[1m'
NC=$'\033[0m'

# Load existing values - improved error handling
if [[ -f "$ENV_FILE" ]]; then
    # Try to source the file, but don't fail if there are issues
    if ! source "$ENV_FILE" 2>/dev/null; then
        echo "WARNING: Failed to source environment file"
        echo "File may contain syntax errors"
        echo -n "Continue without loading saved data? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            return 1 2>/dev/null
        fi
    fi
fi

# Initialize credential sets array if not exists
if ! typeset -gA CRED_SETS 2>/dev/null; then
    echo "ERROR: Failed to create associative array"
    echo "This may indicate a shell compatibility issue"
    return 1 2>/dev/null
fi

# Try to load saved credential sets, but don't fail on error
if [[ -n "$SAVED_CRED_SETS" ]]; then
    eval "CRED_SETS=($SAVED_CRED_SETS)" 2>/dev/null || {
        echo "WARNING: Failed to load saved credential sets"
        echo "Starting with empty credential sets"
    }
fi

# Associative array
typeset -A vars=(
    OUTDIR "$OUTDIR"
    C2 "$C2"
    TARGET "$TARGET"
    TARGETS "$TARGETS"
    CIDR "$CIDR"
    DC "$DC"
    ADCS_HOST "$ADCS_HOST"
    DOMAIN "$DOMAIN"
    USER "$USER"
    PASSWORD "$PASSWORD"
    NT_HASH "$NT_HASH"
    AES_KEY "$AES_KEY"
)

# Ordered keys
ordered_keys=( OUTDIR C2 TARGET TARGETS CIDR DC ADCS_HOST DOMAIN USER PASSWORD NT_HASH AES_KEY)

show_banner() {
    clear
    print -P "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
    print -P "${CYAN}║           ${GREEN}Environment Variables Tool${CYAN}          ║${NC}"
    print -P "${CYAN}║           ${YELLOW}OSCP+ Variable Management${CYAN}           ║${NC}"
    print -P "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
    print ""
}

show_main_display() {
    # Display variables first (starting at 1)
    print -P "${CYAN}Variables:${NC}"
    print -P "${CYAN}─────────${NC}"
    local i=1
    for key in $ordered_keys; do
        printf " ${BOLD}%2d)${NC} ${BLUE}%-20s${NC} : ${GREEN}%s${NC}\n" $i "$key" "${vars[$key]}"
        (( i++ ))
    done
    
    # Display credential sets (continuing from where variables left off)
    if (( ${#CRED_SETS[@]} > 0 )); then
        print -P "\n${CYAN}Credential Sets:${NC}"
        print -P "${CYAN}───────────────${NC}"
        print -P "     ${RED}Password${NC} | ${PURPLE}NT Hash${NC} | ${ORANGE}AES Key${NC}\n"
        for name in ${(k)CRED_SETS}; do
            local cred_data="${CRED_SETS[$name]}"
            local user="${cred_data%%|*}"
            local rest="${cred_data#*|}"
            local password="${rest%%|*}"
            rest="${rest#*|}"
            local nt_hash="${rest%%|*}"
            rest="${rest#*|}"
            local aes_key="${rest%%|*}"
            local target="${rest#*|}"
            
            printf " ${BOLD}%2d)${NC} ${BLUE}%-20s${NC} : " $i "$name"
            printf "${GREEN}%-15s${NC} : " "$user"
            
            # Display auth method with appropriate color
            if [[ -n "$password" ]]; then
                printf "${RED}%s${NC}" "$password"
            elif [[ -n "$nt_hash" ]]; then
                printf "${PURPLE}%s${NC}" "$nt_hash"
            elif [[ -n "$aes_key" ]]; then
                printf "${ORANGE}%s${NC}" "$aes_key"
            else
                printf "${CYAN}(no creds)${NC}"
            fi
            
            # Display target if set
            if [[ -n "$target" ]]; then
                printf " ${CYAN}[%s]${NC}" "$target"
            fi
            
            printf "\n"
            (( i++ ))
        done
    fi
    
    print ""
}

show_main_menu() {
    print -P "${BLUE}═══════════ Main Menu ═══════════${NC}"
    print -P " ${BOLD}${GREEN}A)${NC} Add credential set"
    if (( ${#CRED_SETS[@]} > 0 )); then
        print -P " ${BOLD}${BLUE}E)${NC} Edit credential set"
        print -P " ${BOLD}${RED}D)${NC} Delete credential set"
        print -P " ${BOLD}${YELLOW}X)${NC} Export credentials"
    fi
    print -P " ${BOLD}${PURPLE}C)${NC} Clear all data"
    print -P " ${BOLD}${CYAN}Q)${NC} Exit"
    print -P "${BLUE}═════════════════════════════════${NC}"
}

save_cred_sets() {
    # Add error checking for file operations
    if [[ ! -w "$ENV_FILE" ]] && [[ -f "$ENV_FILE" ]]; then
        print -P "${RED}ERROR: Cannot write to environment file${NC}"
        return 1
    fi
    
    local serialized=""
    for name in ${(k)CRED_SETS}; do
        serialized+="[\"${name//\"/\\\"}\"]=\"${CRED_SETS[$name]}\" "
    done
    
    if grep -v "^SAVED_CRED_SETS=" "$ENV_FILE" 2>/dev/null > "$ENV_FILE.tmp"; then
        echo "SAVED_CRED_SETS='$serialized'" >> "$ENV_FILE.tmp"
        if mv "$ENV_FILE.tmp" "$ENV_FILE" 2>/dev/null; then
            return 0
        else
            print -P "${RED}ERROR: Failed to save credential sets${NC}"
            rm -f "$ENV_FILE.tmp" 2>/dev/null
            return 1
        fi
    else
        print -P "${RED}ERROR: Failed to update environment file${NC}"
        return 1
    fi
}

print_exit_vars() {
    print -P "\n${BOLD}${CYAN}Current Variables:${NC}\n"
    for key in $ordered_keys; do
        printf "     ${BLUE}%-20s${NC} : ${GREEN}%s${NC}\n" "$key" "${vars[$key]}"
    done
    print ""
}

get_key_by_index() {
    echo "${ordered_keys[$1]}"
}

select_cred_set() {
    local name="$1"
    if [[ -n "${CRED_SETS[$name]}" ]]; then
        local cred_data="${CRED_SETS[$name]}"
        local user="${cred_data%%|*}"
        local rest="${cred_data#*|}"
        local password="${rest%%|*}"
        rest="${rest#*|}"
        local nt_hash="${rest%%|*}"
        rest="${rest#*|}"
        local aes_key="${rest%%|*}"
        local target="${rest#*|}"
        
        export USER="$user"
        export PASSWORD="$password"
        export NT_HASH="$nt_hash"
        export AES_KEY="$aes_key"
        [[ -n "$target" ]] && export TARGET="$target" && vars[TARGET]="$target"
        
        vars[USER]="$user"
        vars[PASSWORD]="$password"
        vars[NT_HASH]="$nt_hash"
        vars[AES_KEY]="$aes_key"
        
        for var in USER PASSWORD NT_HASH AES_KEY; do
            grep -v "^$var=" "$ENV_FILE" 2>/dev/null > "$ENV_FILE.tmp"
            mv "$ENV_FILE.tmp" "$ENV_FILE"
        done
        [[ -n "$target" ]] && grep -v "^TARGET=" "$ENV_FILE" 2>/dev/null > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
        
        echo "USER='$user'" >> "$ENV_FILE"
        echo "PASSWORD='$password'" >> "$ENV_FILE"
        echo "NT_HASH='$nt_hash'" >> "$ENV_FILE"
        echo "AES_KEY='$aes_key'" >> "$ENV_FILE"
        [[ -n "$target" ]] && echo "TARGET='$target'" >> "$ENV_FILE"
        
        print -P "${GREEN}Loaded credential set: $name${NC}"
        return 0
    else
        print -P "${RED}Credential set not found: $name${NC}"
        return 1
    fi
}

add_cred_set() {
    read -r "name?${YELLOW}Enter credential set name: ${NC}"
    [[ -z "$name" ]] && print -P "${RED}Name cannot be empty${NC}" && return 1
    
    read -r "user?${YELLOW}Enter username: ${NC}"
    read -r "password?${YELLOW}Enter password (optional): ${NC}"
    read -r "nt_hash?${YELLOW}Enter NT hash (optional): ${NC}"
    read -r "aes_key?${YELLOW}Enter AES key (optional): ${NC}"
    read -r "target?${YELLOW}Enter target (optional): ${NC}"
    
    CRED_SETS[$name]="$user|$password|$nt_hash|$aes_key|$target"
    save_cred_sets
    print -P "${GREEN}Credential set '$name' added${NC}"
}

edit_cred_set() {
    if (( ${#CRED_SETS[@]} == 0 )); then
        print -P "${RED}No credential sets to edit${NC}"
        return 1
    fi
    
    print -P "\n${BOLD}${CYAN}Select credential set to edit:${NC}\n"
    local i=1
    local cred_names=()
    for name in ${(k)CRED_SETS}; do
        cred_names+=("$name")
        local cred_data="${CRED_SETS[$name]}"
        local user="${cred_data%%|*}"
        printf " %2d) %-20s : %s\n" $i "$name" "$user"
        (( i++ ))
    done
    
    print ""
    read -r "sel?${YELLOW}Selection (number or 'cancel'): ${NC}"
    [[ "$sel" == "cancel" ]] && return 0
    
    if [[ "$sel" = [1-9]* ]] && (( sel >= 1 && sel <= ${#cred_names[@]} )); then
        local name="${cred_names[$sel]}"
        local cred_data="${CRED_SETS[$name]}"
        local user="${cred_data%%|*}"
        local rest="${cred_data#*|}"
        local password="${rest%%|*}"
        rest="${rest#*|}"
        local nt_hash="${rest%%|*}"
        rest="${rest#*|}"
        local aes_key="${rest%%|*}"
        local target="${rest#*|}"
        
        print -P "\n${BOLD}Editing: $name${NC}\n"
        
        vared -p "${YELLOW}Username: ${NC}" -c user
        vared -p "${YELLOW}Password: ${NC}" -c password
        vared -p "${YELLOW}NT Hash: ${NC}" -c nt_hash
        vared -p "${YELLOW}AES Key: ${NC}" -c aes_key
        vared -p "${YELLOW}Target: ${NC}" -c target
        
        CRED_SETS[$name]="$user|$password|$nt_hash|$aes_key|$target"
        save_cred_sets
        print -P "\n${GREEN}Updated credential set: $name${NC}"
    else
        print -P "${RED}Invalid selection${NC}"
    fi
}

delete_cred_set() {
    if (( ${#CRED_SETS[@]} == 0 )); then
        print -P "${RED}No credential sets to delete${NC}"
        return 1
    fi
    
    print -P "\n${BOLD}${CYAN}Select credential set to delete:${NC}\n"
    local i=1
    local cred_names=()
    for name in ${(k)CRED_SETS}; do
        cred_names+=("$name")
        printf " %2d) %s\n" $i "$name"
        (( i++ ))
    done
    
    print ""
    read -r "sel?${YELLOW}Selection (number or 'cancel'): ${NC}"
    [[ "$sel" == "cancel" ]] && return 0
    
    if [[ "$sel" = [1-9]* ]] && (( sel >= 1 && sel <= ${#cred_names[@]} )); then
        local name="${cred_names[$sel]}"
        unset "CRED_SETS[$name]"
        save_cred_sets
        print -P "${GREEN}Deleted credential set: $name${NC}"
    else
        print -P "${RED}Invalid selection${NC}"
    fi
}

export_creds() {
    print -P "\n${CYAN}Starting credential export...${NC}"
    
    if (( ${#CRED_SETS[@]} == 0 )); then
        print -P "${RED}No credential sets to export${NC}"
        return 1
    fi
    
    if [[ -z "${vars[OUTDIR]}" ]]; then
        print -P "${RED}OUTDIR not set. Please set OUTDIR first.${NC}"
        return 1
    fi
    
    local outdir="${vars[OUTDIR]}"
    
    # Validate OUTDIR path
    if [[ "$outdir" =~ \.\. ]]; then
        print -P "${RED}ERROR: OUTDIR contains relative path elements (..)${NC}"
        return 1
    fi
    
    print -P "${CYAN}Output directory: $outdir${NC}"
    
    if [[ ! -d "$outdir" ]]; then
        print -P "${YELLOW}Creating directory: $outdir${NC}"
        mkdir -p "$outdir" || {
            print -P "${RED}Failed to create directory: $outdir${NC}"
            return 1
        }
    fi
    
    local users_file="$outdir/users.txt"
    local passwords_file="$outdir/passwords.txt"
    
    [[ -f "$users_file" ]] && rm -f "$users_file"
    [[ -f "$passwords_file" ]] && rm -f "$passwords_file"
    
    local count=0
    
    for name in ${(ko)CRED_SETS}; do
        local cred_data="${CRED_SETS[$name]}"
        
        local IFS='|'
        local parts=()
        parts=(${=cred_data})
        
        local user="${parts[1]:-}"
        local password="${parts[2]:-}"
        
        if [[ -n "$user" ]] && [[ -n "$password" ]]; then
            echo "$user" >> "$users_file"
            echo "$password" >> "$passwords_file"
            (( count++ ))
            print -P "${GREEN}  ✓ Exported: $user${NC}"
        fi
    done
    
    if (( count > 0 )); then
        print -P "\n${GREEN}Successfully exported $count credential(s) to:${NC}"
        print -P "  ${CYAN}→ $users_file${NC}"
        print -P "  ${CYAN}→ $passwords_file${NC}"
    else
        print -P "\n${YELLOW}No credentials with passwords found to export${NC}"
        print -P "${YELLOW}Note: Only credential sets with passwords are exported${NC}"
    fi
    
    print -P "\n${YELLOW}Press Enter to continue...${NC}"
    read -r
    
    return 0
}

clear_all_data() {
    print -P "\n${RED}WARNING: This will delete all variables and credential sets!${NC}"
    print -P "${YELLOW}Are you sure? (yes/NO): ${NC}"
    read -r confirm
    
    if [[ "$confirm" == "yes" ]]; then
        # Use 2>/dev/null to suppress any errors that won't kill the shell
        setopt localoptions nonomatch 2>/dev/null
        for key in $ordered_keys; do
            unset "$key" 2>/dev/null
            vars[$key]=""
        done
        unset CRED_SETS 2>/dev/null
        typeset -gA CRED_SETS
        
        if [[ -w "$ENV_FILE" ]] || [[ ! -f "$ENV_FILE" ]]; then
            > "$ENV_FILE" 2>/dev/null
            print -P "${GREEN}✓ All data cleared successfully${NC}"
        else
            print -P "${RED}WARNING: Could not clear environment file (read-only)${NC}"
            print -P "${YELLOW}Variables cleared from current session only${NC}"
        fi
    else
        print -P "${CYAN}Operation cancelled${NC}"
    fi
    
    print -P "\n${YELLOW}Press Enter to continue...${NC}"
    read -r
}

show_help() {
    print -P "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
    print -P "${CYAN}║           ${GREEN}Environment Variables Tool${CYAN}          ║${NC}"
    print -P "${CYAN}║           ${YELLOW}OSCP+ Variable Management${CYAN}           ║${NC}"
    print -P "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
    print ""
    print -P "${BOLD}USAGE:${NC}"
    print -P "  source var.sh [OPTIONS]"
    print ""
    print -P "${BOLD}DESCRIPTION:${NC}"
    print -P "  Interactive tool for managing environment variables and"
    print -P "  credential sets for penetration testing workflows."
    print ""
    print -P "${BOLD}OPTIONS:${NC}"
    print -P "  ${GREEN}-h, --help${NC}        Show this help message"
    print -P "  ${GREEN}-l, --list${NC}        List all variables and credential sets"
    print -P "  ${GREEN}-s, --source${NC}      Source the environment file and list variables"
    print -P "  ${GREEN}-d, --delete-all${NC}  Delete all variables and credential sets"
    print ""
    print -P "${BOLD}INTERACTIVE MODE:${NC}"
    print -P "  When run without flags, enters interactive mode where you can:"
    print -P "  • Edit variables by entering their number (1-11)"
    print -P "  • Load credential sets by entering their number (12+)"
    print -P "  • ${GREEN}A${NC} - Add new credential set"
    print -P "  • ${BLUE}E${NC} - Edit existing credential set"
    print -P "  • ${RED}D${NC} - Delete credential set"
    print -P "  • ${YELLOW}X${NC} - Export credentials to files"
    print -P "  • ${PURPLE}C${NC} - Clear all data"
    print -P "  • ${CYAN}Q${NC} - Exit"
    print ""
    print -P "${BOLD}VARIABLES MANAGED:${NC}"
    print -P "  OUTDIR    - Output directory for exports"
    print -P "  C2        - Command & Control server"
    print -P "  TARGET    - Target IP/hostname"
    print -P "  TARGETS   - Multiple targets"
    print -P "  CIDR      - Network CIDR notation"
    print -P "  DC        - Domain Controller"
    print -P "  DOMAIN    - Domain name"
    print -P "  USER      - Username"
    print -P "  PASSWORD  - Password"
    print -P "  NT_HASH   - NT hash for pass-the-hash"
    print -P "  AES_KEY   - AES key for Kerberos auth"
    print ""
    print -P "${BOLD}FILES:${NC}"
    print -P "  Config: $ENV_FILE"
    print ""
    print -P "${BOLD}EXAMPLES:${NC}"
    print -P "  ${CYAN}# Enter interactive mode${NC}"
    print -P "  source var.sh"
    print ""
    print -P "  ${CYAN}# List current variables${NC}"
    print -P "  source var.sh -l"
    print ""
    print -P "  ${CYAN}# Source environment and show variables${NC}"
    print -P "  source var.sh -s"
    print ""
}

# Parse command-line flags
if [[ $# -gt 0 ]]; then
    case "$1" in
        -h|--help)
            show_help
            return 0
            ;;
        -s|--source)
            [[ -f "$ENV_FILE" ]] && source "$ENV_FILE" && print -P "${GREEN}Sourced $ENV_FILE${NC}" || print -P "${RED}Env file not found${NC}"
            show_main_display
            return 0
            ;;
        -l|--list)
            [[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
            show_main_display
            return 0
            ;;
        -d|--delete-all)
            set +o nomatch 2>/dev/null
            for key in $ordered_keys; do
                unset "$key"
                unset vars[$key]
            done
            unset CRED_SETS
            typeset -gA CRED_SETS
            set -o nomatch 2>/dev/null
            > "$ENV_FILE" 2>/dev/null
            print -P "${GREEN}All variables deleted and $ENV_FILE cleared.${NC}"
            return 0
            ;;
        -*)
            print -P "${RED}Unknown option: $1${NC}"
            print -P "Use ${GREEN}-h${NC} or ${GREEN}--help${NC} for usage information"
            return 1
            ;;
    esac
fi

# Main interactive loop
while true; do
    show_banner
    show_main_display
    show_main_menu
    
    read -r "sel?${YELLOW}Selection: ${NC}"
    
    # Handle letter commands
    case "${sel:u}" in
        A)
            print ""
            add_cred_set
            print -P "\n${YELLOW}Press Enter to continue...${NC}"
            read -r
            continue
            ;;
        E)
            edit_cred_set
            print -P "\n${YELLOW}Press Enter to continue...${NC}"
            read -r
            continue
            ;;
        D)
            delete_cred_set
            print -P "\n${YELLOW}Press Enter to continue...${NC}"
            read -r
            continue
            ;;
        X)
            export_creds
            continue
            ;;
        C)
            clear_all_data
            continue
            ;;
        Q|EXIT)
            break
            ;;
    esac
    
    # Handle number selections for variables and credential sets
    if [[ "$sel" = [1-9]* ]]; then
        if (( sel >= 1 && sel <= ${#ordered_keys[@]} )); then
            # Variable selection
            key=$(get_key_by_index $sel)
            print ""
            read -r "val?${YELLOW}Enter new value for ${BLUE}$key${NC}: "
            
            export "$key=$val"
            vars[$key]="$val"
            
            # Add error handling for file operations
            if [[ -w "$ENV_FILE" ]] || [[ ! -f "$ENV_FILE" ]]; then
                if grep -v "^$key=" "$ENV_FILE" 2>/dev/null > "$ENV_FILE.tmp"; then
                    echo "$key='$val'" >> "$ENV_FILE.tmp"
                    if mv "$ENV_FILE.tmp" "$ENV_FILE" 2>/dev/null; then
                        print -P "${GREEN}✓ $key updated and saved${NC}"
                    else
                        print -P "${YELLOW}✓ $key updated (session only, save failed)${NC}"
                        rm -f "$ENV_FILE.tmp" 2>/dev/null
                    fi
                else
                    print -P "${YELLOW}✓ $key updated (session only)${NC}"
                fi
            else
                print -P "${YELLOW}✓ $key updated (session only, file is read-only)${NC}"
            fi
            
            print -P "\n${YELLOW}Press Enter to continue...${NC}"
            read -r
        elif (( sel > ${#ordered_keys[@]} )); then
            # Credential set selection
            local cred_index=$((sel - ${#ordered_keys[@]}))
            local cred_names=()
            for name in ${(k)CRED_SETS}; do
                cred_names+=("$name")
            done
            
            if (( cred_index >= 1 && cred_index <= ${#cred_names[@]} )); then
                select_cred_set "${cred_names[$cred_index]}"
                print -P "\n${YELLOW}Press Enter to continue...${NC}"
                read -r
            else
                print -P "${RED}Invalid selection${NC}"
                print -P "\n${YELLOW}Press Enter to continue...${NC}"
                read -r
            fi
        else
            print -P "${RED}Invalid selection${NC}"
            print -P "\n${YELLOW}Press Enter to continue...${NC}"
            read -r
        fi
    elif [[ -n "$sel" ]]; then
        print -P "${RED}Invalid option${NC}"
        print -P "\n${YELLOW}Press Enter to continue...${NC}"
        read -r
    fi
done

# Exit sequence
clear
print_exit_vars
print -P "${CYAN}Variables saved to $ENV_FILE${NC}"
print -P "${CYAN}Source it in future shells to load.${NC}"