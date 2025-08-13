#!/usr/bin/env bash
# ipmap - Add, Delete, List IP↔Hostname mappings in /etc/hosts
# Usage:
#   ipmap a <hostname> <ip>   # Add mapping
#   ipmap d <hostname|all>    # Delete hostname mapping or all script-managed entries
#   ipmap l <hostname>        # List IP for given hostname
#   ipmap                     # List all script-managed entries

HOSTS_FILE="/etc/hosts"
TAG="# ipmap"

usage() {
    echo "Usage:"
    echo "  $0 a <hostname> <ip>     Add hostname mapping"
    echo "  $0 d <hostname|all>      Delete hostname mapping or all ipmap entries"
    echo "  $0 l <hostname>          List IP for given hostname"
    echo "  $0                       List all managed entries"
    exit 1
}

[ "$EUID" -ne 0 ] && echo "Run as root to modify /etc/hosts" && exit 1

case "$1" in
    a)
        [ $# -ne 3 ] && usage
        HOST="$2"
        IP="$3"
        # Remove any existing entry for the hostname
        sed -i.bak "/[[:space:]]$HOST[[:space:]]*$TAG/d" "$HOSTS_FILE"
        echo "$IP    $HOST    $TAG" >> "$HOSTS_FILE"
        echo "Added: $HOST -> $IP"
        ;;
    d)
        [ $# -ne 2 ] && usage
        if [ "$2" = "all" ]; then
            sed -i.bak "/$TAG/d" "$HOSTS_FILE"
            echo "All ipmap entries removed."
        else
            HOST="$2"
            sed -i.bak "/[[:space:]]$HOST[[:space:]]*$TAG/d" "$HOSTS_FILE"
            echo "Deleted: $HOST"
        fi
        ;;
    l)
        [ $# -ne 2 ] && usage
        HOST="$2"
        grep "[[:space:]]$HOST[[:space:]]*$TAG" "$HOSTS_FILE" | awk '{print $1}'
        ;;
    "")
        grep "$TAG" "$HOSTS_FILE" | awk '{print $2, "->", $1}'
        ;;
    *)
        usage
        ;;
esac
