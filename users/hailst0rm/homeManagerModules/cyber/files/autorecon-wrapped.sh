#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Usage function
usage() {
    cat << EOF
Usage: sudo autorecon-wrapped -o OUTDIR [-t TARGET...] [-c CIDR] [-PE] [--tags TAGS] [-u USER] [-p PASSWORD] [-H NT_HASH] [--aesKey AES_KEY] [--use-kcache] [-d DOMAIN] [-dc-ip IP]

Automated reconnaissance wrapper for rustscan, nmap, and autorecon.
Must be run with sudo. Privileged tools (nmap, autorecon) run as root;
everything else runs as the invoking user.

OPTIONS:
    -o OUTDIR    Output directory for scan results (required)
    -t TARGET    (Optional) Target IP address, DNS name, or list of targets
                 Multiple -t flags, comma-separated, and space-separated all work.
                 Supports IP ranges: 192.168.1.0-10 expands to .0 through .10
    -c CIDR      (Optional) CIDR range for NetExec SMB enumeration
                 Example: "192.168.1.0/24"
    -PE          (Optional) Add ICMP echo request to nmap scans (--nmap-append='-PE')
    -u USER      (Optional) Username for authentication (--global.username)
    -p PASSWORD  (Optional) Password for authentication (--global.password)
    -H NT_HASH   (Optional) NT hash for authentication (--global.nthash)
    --aesKey KEY (Optional) AES key for authentication (--global.aeskey)
    --use-kcache (Optional) Use Kerberos ccache ticket (--global.ticket)
    -d DOMAIN    (Optional) Domain for authentication (--global.domain)
    -dc-ip IP    (Optional) Domain Controller IP (--global.dcip)
    --tags TAGS  (Optional) Tags to determine which plugins should be included
                 Separate tags by + to group, separate groups with ,
                 Example: "ad-auth+enum" or "default,http"
    -h           Show this help message

NOTE: At least one of -t or -c must be provided.

EXAMPLES:
    sudo autorecon-wrapped -o ./scans -t 192.168.1.1
    sudo autorecon-wrapped -o ./scans -t 192.168.1.1 192.168.1.2
    sudo autorecon-wrapped -o ./scans -t 192.168.1.0-10
    sudo autorecon-wrapped -o ./scans -t target1.com,target2.com
    sudo autorecon-wrapped -o ./scans -c 192.168.1.0/24
    sudo autorecon-wrapped -o ./scans -t 192.168.1.1 -c 192.168.1.0/24
    sudo autorecon-wrapped -o ./scans -t 192.168.1.1 --tags ad-auth+enum

EOF
    exit 1
}

# Expand IP ranges like 192.168.1.0-10 into individual IPs
expand_range() {
    local input="$1"
    if [[ "$input" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.)([0-9]+)-([0-9]+)$ ]]; then
        local prefix="${BASH_REMATCH[1]}"
        local start="${BASH_REMATCH[2]}"
        local end="${BASH_REMATCH[3]}"
        for ((i=start; i<=end; i++)); do
            echo "${prefix}${i}"
        done
    else
        echo "$input"
    fi
}

# Require root (via sudo)
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run with sudo${NC}"
    echo "Example: sudo autorecon-wrapped -o ./scans -t 192.168.1.1"
    exit 1
fi

if [[ -z "$SUDO_USER" ]]; then
    echo -e "${RED}Error: SUDO_USER is not set. Run this script via sudo, not as root directly.${NC}"
    exit 1
fi

# Resolve the invoking user's home and PATH for dropping privileges
REAL_USER="$SUDO_USER"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
REAL_GID=$(getent passwd "$REAL_USER" | cut -d: -f4)
REAL_GROUP=$(getent group "$REAL_GID" | cut -d: -f1)

# Helper: run a command as the invoking user (with their environment)
run_as_user() {
    sudo -u "$REAL_USER" --preserve-env=PATH,KRB5_CONFIG,KRB5CCNAME HOME="$REAL_HOME" "$@"
}

# Parse command line arguments
TARGETS=""
OUTDIR=""
CIDR=""
NMAP_PE=""
TAGS=""
USER=""
PASSWORD=""
NT_HASH=""
AES_KEY=""
USE_KCACHE=""
DOMAIN=""
DCIP=""

# Handle long options before getopts
for arg in "$@"; do
    shift
    case "$arg" in
        "-PE"|"--PE")
            NMAP_PE="--nmap-append='-PE'"
            continue
            ;;
        "--tags")
            set -- "$@" "-T"
            ;;
        "--tags="*)
            TAGS="${arg#*=}"
            continue
            ;;
        "--aesKey")
            set -- "$@" "-A"
            ;;
        "--aesKey="*)
            AES_KEY="${arg#*=}"
            continue
            ;;
        "--use-kcache")
            USE_KCACHE="true"
            continue
            ;;
        "-dc-ip")
            set -- "$@" "-D"
            ;;
        *)
            set -- "$@" "$arg"
            ;;
    esac
done

while getopts "t:o:c:T:u:p:H:A:d:D:h" opt; do
    case $opt in
        t)
            TARGETS="$OPTARG"
            ;;
        o)
            OUTDIR="$OPTARG"
            ;;
        c)
            CIDR="$OPTARG"
            ;;
        T)
            TAGS="$OPTARG"
            ;;
        u)
            USER="$OPTARG"
            ;;
        p)
            PASSWORD="$OPTARG"
            ;;
        H)
            NT_HASH="$OPTARG"
            ;;
        A)
            AES_KEY="$OPTARG"
            ;;
        d)
            DOMAIN="$OPTARG"
            ;;
        D)
            DCIP="$OPTARG"
            ;;
        h)
            usage
            ;;
        \?)
            echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2
            usage
            ;;
        :)
            echo -e "${RED}Option -$OPTARG requires an argument.${NC}" >&2
            usage
            ;;
    esac
done

# Collect remaining positional arguments as additional targets
shift $((OPTIND - 1))
for arg in "$@"; do
    if [[ -n "$TARGETS" ]]; then
        TARGETS="$TARGETS $arg"
    else
        TARGETS="$arg"
    fi
done

# Validate required arguments
if [[ -z "$OUTDIR" ]]; then
    echo -e "${RED}Error: Output directory (-o) is required${NC}"
    usage
fi

if [[ -z "$TARGETS" && -z "$CIDR" ]]; then
    echo -e "${RED}Error: At least one of -t (target) or -c (CIDR) must be provided${NC}"
    usage
fi

# Check for required tools (check as user since tools are in user's PATH)
MISSING_TOOLS=()
if [[ -n "$TARGETS" ]]; then
    for tool in rustscan nmap autorecon; do
        if ! run_as_user bash -c "command -v $tool" &> /dev/null; then
            MISSING_TOOLS+=("$tool")
        fi
    done
fi

# Check for CIDR-specific tools if CIDR is provided
if [[ -n "$CIDR" ]]; then
    for tool in nxc ipmap; do
        if ! run_as_user bash -c "command -v $tool" &> /dev/null; then
            MISSING_TOOLS+=("$tool")
        fi
    done
fi

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    echo -e "${RED}Error: The following required tools are not installed:${NC}"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo -e "${RED}  - $tool${NC}"
    done
    exit 1
fi

# Create output directory (owned by invoking user so non-root tools can write)
mkdir -p "$OUTDIR"
chown "$REAL_USER":"$REAL_GROUP" "$OUTDIR"

# Process CIDR if provided
if [[ -n "$CIDR" ]]; then
    echo -e "${GREEN}[*] Processing CIDR range: $CIDR${NC}"

    # Host discovery scan (root: needs raw sockets)
    echo -e "${YELLOW}[*] Running host discovery scan on CIDR range${NC}"
    nmap -PE -PM -PP -sn -n "$CIDR" -oG "$OUTDIR/host-discovery.gnmap"

    if [[ -f "$OUTDIR/host-discovery.gnmap" ]]; then
        echo -e "${GREEN}[+] Host discovery completed: $OUTDIR/host-discovery.gnmap${NC}"
    else
        echo -e "${RED}[!] Failed to perform host discovery${NC}"
    fi

    # Generate hosts file (user: nxc uses user config)
    echo -e "${YELLOW}[*] Generating hosts file from CIDR range${NC}"
    run_as_user nxc smb "$CIDR" --generate-hosts-file "$OUTDIR/hosts.txt"

    if [[ -f "$OUTDIR/hosts.txt" ]]; then
        echo -e "${YELLOW}[*] Loading hosts file into IP mapping${NC}"
        ipmap m "$OUTDIR/hosts.txt"
        echo -e "${GREEN}[+] Hosts file loaded successfully from: $OUTDIR/hosts.txt${NC}"
    else
        echo -e "${RED}[!] Failed to generate hosts file${NC}"
    fi

    # Generate Kerberos config (user: nxc uses user config)
    echo -e "${YELLOW}[*] Generating Kerberos configuration${NC}"
    run_as_user nxc smb "$CIDR" --generate-krb5-file "$OUTDIR/krb5.conf"

    if [[ -f "$OUTDIR/krb5.conf" ]]; then
        export KRB5_CONFIG="$OUTDIR/krb5.conf"

        # Update or create ~/.config/.my_vars.env (as user)
        run_as_user mkdir -p "$REAL_HOME/.config"
        if [[ -f "$REAL_HOME/.config/.my_vars.env" ]]; then
            if grep -q "^KRB5_CONFIG=" "$REAL_HOME/.config/.my_vars.env"; then
                # Replace existing entry
                sed -i "s|^KRB5_CONFIG=.*|KRB5_CONFIG='$OUTDIR/krb5.conf'|" "$REAL_HOME/.config/.my_vars.env"
            else
                # Add new entry
                echo "KRB5_CONFIG='$OUTDIR/krb5.conf'" >> "$REAL_HOME/.config/.my_vars.env"
            fi
        else
            # Create file with entry
            echo "KRB5_CONFIG='$OUTDIR/krb5.conf'" > "$REAL_HOME/.config/.my_vars.env"
        fi
        chown "$REAL_USER":"$REAL_GROUP" "$REAL_HOME/.config/.my_vars.env"

        echo -e "${GREEN}[+] Kerberos configuration loaded and exported: KRB5_CONFIG=$OUTDIR/krb5.conf${NC}"
        echo -e "${GREEN}[+] KRB5_CONFIG saved to ~/.config/.my_vars.env${NC}"
    else
        echo -e "${RED}[!] Failed to generate Kerberos configuration${NC}"
    fi

    # Parse discovered hosts and ask user
    if [[ -f "$OUTDIR/host-discovery.gnmap" ]]; then
        DISCOVERED_HOSTS=$(grep "Status: Up" "$OUTDIR/host-discovery.gnmap" | grep -oP 'Host: \K[0-9.]+')

        if [[ -n "$DISCOVERED_HOSTS" ]]; then
            echo ""
            echo -e "${GREEN}Hosts found:${NC}"
            echo "$DISCOVERED_HOSTS"
            echo ""

            read -p "Do you want to run target enumeration on these hosts? [Y/n]: " -r
            echo

            if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                # Convert to space-separated list
                TARGET_LIST=$(echo "$DISCOVERED_HOSTS" | tr '\n' ' ' | sed 's/ $//')
                echo -e "${GREEN}[*] Rerunning with discovered targets${NC}"
                echo ""

                # Build command for recursive call, preserving flags
                RECURS_CMD="$0 -o \"$OUTDIR\" -t \"$TARGET_LIST\""

                if [[ -n "$NMAP_PE" ]]; then
                    RECURS_CMD="$RECURS_CMD -PE"
                fi

                if [[ -n "$TAGS" ]]; then
                    RECURS_CMD="$RECURS_CMD --tags \"$TAGS\""
                fi

                if [[ -n "$USER" ]]; then
                    RECURS_CMD="$RECURS_CMD -u \"$USER\""
                fi

                if [[ -n "$PASSWORD" ]]; then
                    RECURS_CMD="$RECURS_CMD -p \"$PASSWORD\""
                fi

                if [[ -n "$NT_HASH" ]]; then
                    RECURS_CMD="$RECURS_CMD -H \"$NT_HASH\""
                fi

                if [[ -n "$AES_KEY" ]]; then
                    RECURS_CMD="$RECURS_CMD --aesKey \"$AES_KEY\""
                fi

                if [[ -n "$USE_KCACHE" ]]; then
                    RECURS_CMD="$RECURS_CMD --use-kcache"
                fi

                if [[ -n "$DOMAIN" ]]; then
                    RECURS_CMD="$RECURS_CMD -d \"$DOMAIN\""
                fi

                if [[ -n "$DCIP" ]]; then
                    RECURS_CMD="$RECURS_CMD -dc-ip \"$DCIP\""
                fi

                eval "exec $RECURS_CMD"
            else
                echo -e "${YELLOW}[*] Skipping target enumeration${NC}"
            fi
        else
            echo -e "${YELLOW}[!] No hosts discovered in CIDR range${NC}"
        fi
    fi

    echo ""
fi

# Process targets if provided
if [[ -n "$TARGETS" ]]; then
    # Normalize targets: replace commas with spaces, then expand IP ranges
    TARGETS=$(echo "$TARGETS" | tr ',' ' ')
    EXPANDED=""
    for raw in $TARGETS; do
        EXPANDED="$EXPANDED $(expand_range "$raw")"
    done
    TARGETS=$(echo "$EXPANDED" | xargs)

    # Process each target
    for t in $(echo "$TARGETS" | tr ' ' '\n'); do
    echo -e "${GREEN}[*] Processing target: $t${NC}"

    mkdir -p "$OUTDIR/$t"
    chown "$REAL_USER":"$REAL_GROUP" "$OUTDIR/$t"

    # rustscan doesn't need root
    echo -e "${YELLOW}[*] Running rustscan on $t${NC}"
    run_as_user rustscan -a $t -r 0-65535 -g | tee "$OUTDIR/$t/TCP.txt"

    # nmap UDP scan needs root (raw sockets)
    echo -e "${YELLOW}[*] Running UDP scan on $t${NC}"
    nmap -vv --reason -Pn -sU --top-ports 100 -oN "$OUTDIR/$t/UDP.txt" $t

    TCP_PORTS=$(grep -oP '\[\K[0-9,]+(?=\])' "$OUTDIR/$t/TCP.txt" | head -1)
    UDP_PORTS=$(grep -oP '^\d+(?=/udp\s+open)' "$OUTDIR/$t/UDP.txt" | tr '\n' ',' | sed 's/,$//')

    PORTS=""
    if [[ -n "$TCP_PORTS" ]]; then
        PORTS="T:${TCP_PORTS}"
    fi
    if [[ -n "$UDP_PORTS" ]]; then
        if [[ -n "$PORTS" ]]; then
            PORTS="${PORTS},U:${UDP_PORTS}"
        else
            PORTS="U:${UDP_PORTS}"
        fi
    fi

    if [[ -n "$PORTS" ]]; then
        echo -e "${YELLOW}[*] Running autorecon on $t with ports: $PORTS${NC}"

        # Build autorecon command with optional flags
        # autorecon needs root for nmap raw sockets; HOME is set to user's home
        # so child processes (nxc, etc.) find the correct config files
        # PATH includes user's profile so plugin check() calls (shutil.which) find user-installed tools
        AUTORECON_CMD="HOME=$REAL_HOME PATH=/etc/profiles/per-user/$REAL_USER/bin:\$PATH KRB5CCNAME=\"${KRB5CCNAME:-/tmp/krb5cc_$REAL_UID}\" autorecon \"$t\" --ports $PORTS --config \"$REAL_HOME/cyber/AutoRecon/config.toml\" --global-file \"$REAL_HOME/cyber/AutoRecon/global.toml\" --plugins-dir \"$REAL_HOME/cyber/AutoRecon/Plugins\" --wpscan.api-token uhagbSupFhQPEsOzhP7VyA1FSuKoG8qx9WwXrWsWL4I --exclude-tags disabled --disable-keyboard-control --output \"$OUTDIR\""

        if [[ -n "$NMAP_PE" ]]; then
            AUTORECON_CMD="$AUTORECON_CMD $NMAP_PE"
        fi

        if [[ -n "$TAGS" ]]; then
            AUTORECON_CMD="$AUTORECON_CMD --tags default-port-scan,$TAGS"
        fi

        if [[ -n "$USER" ]]; then
            AUTORECON_CMD="$AUTORECON_CMD --global.username $USER"
        fi

        if [[ -n "$PASSWORD" ]]; then
            AUTORECON_CMD="$AUTORECON_CMD --global.password $PASSWORD"
        fi

        if [[ -n "$NT_HASH" ]]; then
            AUTORECON_CMD="$AUTORECON_CMD --global.nthash $NT_HASH"
        fi

        if [[ -n "$AES_KEY" ]]; then
            AUTORECON_CMD="$AUTORECON_CMD --global.aeskey $AES_KEY"
        fi

        if [[ -n "$USE_KCACHE" ]]; then
            AUTORECON_CMD="$AUTORECON_CMD --global.ticket true"
        fi

        if [[ -n "$DOMAIN" ]]; then
            AUTORECON_CMD="$AUTORECON_CMD --global.domain $DOMAIN"
        fi

        if [[ -n "$DCIP" ]]; then
            AUTORECON_CMD="$AUTORECON_CMD --global.dcip $DCIP"
        fi

        echo -e "${BLUE}[+] Running: $AUTORECON_CMD${NC}"
        eval "$AUTORECON_CMD &"
    else
        echo -e "${RED}[!] No open ports found for $t, skipping autorecon${NC}"
    fi
    done

    # Wait for all background jobs to complete
    wait

    # Fix ownership of output directory so user can access results
    chown -R "$REAL_USER":"$REAL_GROUP" "$OUTDIR"

    echo -e "${GREEN}[*] All target scans completed${NC}"
fi

echo -e "${GREEN}[*] All operations completed. Results saved to: $OUTDIR${NC}"
