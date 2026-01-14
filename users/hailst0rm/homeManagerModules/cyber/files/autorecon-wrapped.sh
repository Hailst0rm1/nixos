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
Usage: autorecon-wrapped -o OUTDIR [-t TARGET] [-c CIDR] [-PE] [--tags TAGS] [-u USER] [-p PASSWORD] [-H NT_HASH] [-d DOMAIN]

Automated reconnaissance wrapper for rustscan, nmap, and autorecon.

OPTIONS:
    -o OUTDIR    Output directory for scan results (required)
    -t TARGET    (Optional) Target IP address, DNS name, or list of targets
                 Formats: "192.168.1.1" or "target1 target2" or "target1,target2"
    -c CIDR      (Optional) CIDR range for NetExec SMB enumeration
                 Example: "192.168.1.0/24"
    -PE          (Optional) Add ICMP echo request to nmap scans (--nmap-append='-PE')
    -u USER      (Optional) Username for authentication (--global.username)
    -p PASSWORD  (Optional) Password for authentication (--global.password)
    -H NT_HASH   (Optional) NT hash for authentication (--global.nthash)
    -d DOMAIN    (Optional) Domain for authentication (--global.domain)
    --tags TAGS  (Optional) Tags to determine which plugins should be included
                 Separate tags by + to group, separate groups with ,
                 Example: "ad-auth+enum" or "default,http"
    -h           Show this help message

NOTE: At least one of -t or -c must be provided.

EXAMPLES:
    autorecon-wrapped -o ./scans -t 192.168.1.1
    autorecon-wrapped -o ./scans -t "192.168.1.1 192.168.1.2"
    autorecon-wrapped -o ./scans -t "target1.com,target2.com"
    autorecon-wrapped -o ./scans -c 192.168.1.0/24
    autorecon-wrapped -o ./scans -t 192.168.1.1 -c 192.168.1.0/24
    autorecon-wrapped -o ./scans -t 192.168.1.1 --tags ad-auth+enum
    autorecon-wrapped -o ./scans -t 192.168.1.1 --tags ad-auth+enum

EOF
    exit 1
}

# Check if running as sudo
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Error: This script should not be run as sudo/root${NC}"
    echo "The script will elevate privileges when needed internally."
    exit 1
fi

# Parse command line arguments
TARGETS=""
OUTDIR=""
CIDR=""
NMAP_PE=""
TAGS=""
USER=""
PASSWORD=""
NT_HASH=""
DOMAIN=""

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
        *)
            set -- "$@" "$arg"
            ;;
    esac
done

while getopts "t:o:c:T:u:p:H:d:h" opt; do
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
        d)
            DOMAIN="$OPTARG"
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

# Validate required arguments
if [[ -z "$OUTDIR" ]]; then
    echo -e "${RED}Error: Output directory (-o) is required${NC}"
    usage
fi

if [[ -z "$TARGETS" && -z "$CIDR" ]]; then
    echo -e "${RED}Error: At least one of -t (target) or -c (CIDR) must be provided${NC}"
    usage
fi

# Check for required tools
MISSING_TOOLS=()
if [[ -n "$TARGETS" ]]; then
    for tool in rustscan nmap autorecon; do
        if ! command -v $tool &> /dev/null; then
            MISSING_TOOLS+=("$tool")
        fi
    done
fi

# Check for CIDR-specific tools if CIDR is provided
if [[ -n "$CIDR" ]]; then
    for tool in nxc ipmap; do
        if ! command -v $tool &> /dev/null; then
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

# Create output directory
mkdir -p "$OUTDIR"

# Process CIDR if provided
if [[ -n "$CIDR" ]]; then
    echo -e "${GREEN}[*] Processing CIDR range: $CIDR${NC}"
    
    # Host discovery scan
    echo -e "${YELLOW}[*] Running host discovery scan on CIDR range${NC}"
    sudo nmap -PE -PM -PP -sn -n "$CIDR" -oG "$OUTDIR/host-discovery.gnmap"
    
    if [[ -f "$OUTDIR/host-discovery.gnmap" ]]; then
        echo -e "${GREEN}[+] Host discovery completed: $OUTDIR/host-discovery.gnmap${NC}"
    else
        echo -e "${RED}[!] Failed to perform host discovery${NC}"
    fi
    
    # Generate hosts file
    echo -e "${YELLOW}[*] Generating hosts file from CIDR range${NC}"
    nxc smb "$CIDR" --generate-hosts-file "$OUTDIR/hosts.txt"
    
    if [[ -f "$OUTDIR/hosts.txt" ]]; then
        echo -e "${YELLOW}[*] Loading hosts file into IP mapping${NC}"
        sudo ipmap m "$OUTDIR/hosts.txt"
        echo -e "${GREEN}[+] Hosts file loaded successfully from: $OUTDIR/hosts.txt${NC}"
    else
        echo -e "${RED}[!] Failed to generate hosts file${NC}"
    fi
    
    # Generate Kerberos config
    echo -e "${YELLOW}[*] Generating Kerberos configuration${NC}"
    nxc smb "$CIDR" --generate-krb5-file "$OUTDIR/krb5.conf"
    
    if [[ -f "$OUTDIR/krb5.conf" ]]; then
        export KRB5_CONFIG="$OUTDIR/krb5.conf"
        
        # Update or create ~/.config/.my_vars.env
        mkdir -p ~/.config
        if [[ -f ~/.config/.my_vars.env ]]; then
            if grep -q "^KRB5_CONFIG=" ~/.config/.my_vars.env; then
                # Replace existing entry
                sed -i "s|^KRB5_CONFIG=.*|KRB5_CONFIG='$OUTDIR/krb5.conf'|" ~/.config/.my_vars.env
            else
                # Add new entry
                echo "KRB5_CONFIG='$OUTDIR/krb5.conf'" >> ~/.config/.my_vars.env
            fi
        else
            # Create file with entry
            echo "KRB5_CONFIG='$OUTDIR/krb5.conf'" > ~/.config/.my_vars.env
        fi
        
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
                
                if [[ -n "$DOMAIN" ]]; then
                    RECURS_CMD="$RECURS_CMD -d \"$DOMAIN\""
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
    # Normalize targets: replace commas with spaces
    TARGETS=$(echo "$TARGETS" | tr ',' ' ')

    # Process each target
    for t in $(echo "$TARGETS" | tr ' ' '\n'); do
    echo -e "${GREEN}[*] Processing target: $t${NC}"
    
    sudo mkdir -p "$OUTDIR/$t"
    
    echo -e "${YELLOW}[*] Running rustscan on $t${NC}"
    rustscan -a $t -r 0-65535 -g | sudo tee "$OUTDIR/$t/TCP.txt"
    
    echo -e "${YELLOW}[*] Running UDP scan on $t${NC}"
    sudo nmap -vv --reason -Pn -sU --top-ports 100 -oN "$OUTDIR/$t/UDP.txt" $t
    
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
        AUTORECON_CMD="sudo autorecon \"$t\" --ports $PORTS --config ~/cyber/AutoRecon/config.toml --global-file ~/cyber/AutoRecon/global.toml --plugins-dir ~/cyber/AutoRecon/Plugins --wpscan.api-token uhagbSupFhQPEsOzhP7VyA1FSuKoG8qx9WwXrWsWL4I --exclude-tags disabled --output \"$OUTDIR\""
        
        if [[ -n "$NMAP_PE" ]]; then
            AUTORECON_CMD="$AUTORECON_CMD $NMAP_PE"
        fi
        
        if [[ -n "$TAGS" ]]; then
            AUTORECON_CMD="$AUTORECON_CMD --tags $TAGS"
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
        
        if [[ -n "$DOMAIN" ]]; then
            AUTORECON_CMD="$AUTORECON_CMD --global.domain $DOMAIN"
        fi
        
        eval "$AUTORECON_CMD &"
    else
        echo -e "${RED}[!] No open ports found for $t, skipping autorecon${NC}"
    fi
    done

    # Wait for all background jobs to complete
    wait
    
    echo -e "${GREEN}[*] All target scans completed${NC}"
fi

echo -e "${GREEN}[*] All operations completed. Results saved to: $OUTDIR${NC}"