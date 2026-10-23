#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# DEFAULT PUBLIC KEY
# (Default fallback for Shubham's local Mac)
# ==============================================================================
DEFAULT_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpMcx7qyhtxaZ4EuAlS2EQwa145fO8/g5fvIES4vsty shubh@Shubhams-MacBook-Air.local"
# ==============================================================================

show_help() {
    cat <<EOF
Usage: setup-ssh.sh [OPTIONS] [PUBLIC_KEY]

Configures SSH access on the current machine by adding an authorized public key,
setting secure file permissions, and ensuring the SSH server daemon is running.

Options:
  -k, --key <KEY_STRING>      Custom public key string to authorize
  -g, --github <USERNAME>     Fetch and authorize public keys from GitHub user
  -h, --help                  Show this help message

Examples:
  # Use default embedded public key:
  ./setup-ssh.sh

  # Pass custom key:
  ./setup-ssh.sh "ssh-ed25519 AAAA... user@host"

  # Fetch key from GitHub:
  ./setup-ssh.sh --github ShubhamBhavsar101

  # Run via curl:
  curl -fsSL https://raw.githubusercontent.com/ShubhamBhavsar101/scripts/main/ssh/setup-ssh.sh | bash
EOF
}

TARGET_KEY=""
GITHUB_USER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -k|--key)
            TARGET_KEY="$2"
            shift 2
            ;;
        -g|--github)
            GITHUB_USER="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$TARGET_KEY" ]]; then
                TARGET_KEY="$1"
                shift
            else
                echo "[-] Unknown argument: $1" >&2
                show_help
                exit 1
            fi
            ;;
    esac
done

# If GitHub username was passed, download public keys
if [[ -n "$GITHUB_USER" ]]; then
    echo "[*] Fetching public keys for GitHub user: ${GITHUB_USER}..."
    TARGET_KEY=$(curl -fsSL "https://github.com/${GITHUB_USER}.keys" || true)
    if [[ -z "$TARGET_KEY" ]]; then
        echo "[-] Error: Failed to retrieve keys for GitHub user '${GITHUB_USER}' or user has no public keys." >&2
        exit 1
    fi
fi

# Fallback to default key if none provided
if [[ -z "$TARGET_KEY" ]]; then
    TARGET_KEY="$DEFAULT_KEY"
fi

CURRENT_USER="${USER:-$(whoami)}"
SSH_DIR="${HOME}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"

echo "[+] Setting up SSH access for user '${CURRENT_USER}'..."

# 1. Create and secure ~/.ssh directory
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

# 2. Append keys idempotently
touch "${AUTH_KEYS}"
ADDED_COUNT=0

while IFS= read -r key_line || [[ -n "$key_line" ]]; do
    # Skip empty lines or comments
    [[ -z "$key_line" || "$key_line" =~ ^[[:space:]]*# ]] && continue

    if grep -Fxq "${key_line}" "${AUTH_KEYS}"; then
        echo "[*] Key already exists in ${AUTH_KEYS}."
    else
        echo "${key_line}" >> "${AUTH_KEYS}"
        ADDED_COUNT=$((ADDED_COUNT + 1))
        echo "[+] Public key added."
    fi
done <<< "$TARGET_KEY"

# 3. Ensure proper permissions on authorized_keys (600)
chmod 600 "${AUTH_KEYS}"

# 4. Check & install OpenSSH server daemon if not installed
SUDO=""
if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
fi

if ! command -v sshd >/dev/null 2>&1; then
    echo "[*] sshd binary not found. Attempting to install OpenSSH server..."
    if command -v apt-get >/dev/null 2>&1; then
        $SUDO apt-get update -y && $SUDO apt-get install -y openssh-server
    elif command -v dnf >/dev/null 2>&1; then
        $SUDO dnf install -y openssh-server
    elif command -v yum >/dev/null 2>&1; then
        $SUDO yum install -y openssh-server
    elif command -v pacman >/dev/null 2>&1; then
        $SUDO pacman -Sy --noconfirm openssh
    elif command -v apk >/dev/null 2>&1; then
        $SUDO apk add --no-cache openssh
    else
        echo "[!] Warning: Package manager not recognized. Please install openssh-server manually." >&2
    fi
fi

# 5. Ensure SSH service is running
if command -v systemctl >/dev/null 2>&1; then
    $SUDO systemctl enable --now ssh 2>/dev/null || $SUDO systemctl enable --now sshd 2>/dev/null || true
elif command -v service >/dev/null 2>&1; then
    $SUDO service ssh start 2>/dev/null || $SUDO service sshd start 2>/dev/null || true
fi

# 6. Print connection helper details
PRIMARY_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
if [[ -z "$PRIMARY_IP" ]]; then
    PRIMARY_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' || true)
fi
if [[ -z "$PRIMARY_IP" ]]; then
    PRIMARY_IP="<TARGET_IP>"
fi

echo "=================================================="
echo "[✓] SSH access successfully configured!"
echo "    User: ${CURRENT_USER}"
echo "    Authorized Keys: ${AUTH_KEYS}"
echo ""
echo "Connect from your PC:"
echo "    ssh ${CURRENT_USER}@${PRIMARY_IP}"
echo "=================================================="
