#!/usr/bin/env bash
#
# uninstall.sh - Completely remove code-server
# Developed by Shubham Bhavsar
#

set -euo pipefail

PURGE_DATA=false
ASSUME_YES=false

show_help() {
  cat << 'EOF'
Usage: uninstall.sh [OPTIONS]

Safely stops and uninstalls code-server regardless of how it was installed
(apt, dnf, pacman, brew, npm, or standalone binary).

Options:
  -p, --purge    Also delete user configs, extensions, and cached data
                 (~/.config/code-server and ~/.local/share/code-server)
  -y, --yes      Assume yes to all confirmation prompts (non-interactive)
  -h, --help     Show this help message and exit

Examples:
  ./uninstall.sh            # Removes code-server binary and service
  ./uninstall.sh --purge    # Completely wipes code-server and its configurations
  ./uninstall.sh -y --purge # Non-interactive full purge
EOF
}

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -p|--purge)
      PURGE_DATA=true
      shift
      ;;
    -y|--yes)
      ASSUME_YES=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_help
      exit 1
      ;;
  esac
done

run_elevated() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "Warning: Command '$*' requires root permissions, but sudo was not found." >&2
  fi
}

echo "=========================================="
echo " code-server Uninstaller"
echo " Purge User Data : ${PURGE_DATA}"
echo "=========================================="

if [[ "$ASSUME_YES" != true ]]; then
  read -r -p "Are you sure you want to uninstall code-server? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY])
      ;;
    *)
      echo "Uninstallation cancelled."
      exit 0
      ;;
  esac
fi

# 1. Stop running processes
echo "[1/4] Stopping active code-server processes..."
if pgrep -f "code-server" >/dev/null 2>&1; then
  echo "Terminating running code-server instances..."
  pkill -f "code-server" 2>/dev/null || true
  sleep 1
fi

# 2. Stop and disable systemd service (if systemd exists)
echo "[2/4] Checking and stopping systemd services..."
if command -v systemctl >/dev/null 2>&1; then
  CURRENT_USER="${USER:-$(id -un)}"
  if systemctl is-active --quiet "code-server@${CURRENT_USER}" 2>/dev/null; then
    echo "Stopping systemd service: code-server@${CURRENT_USER}..."
    run_elevated systemctl stop "code-server@${CURRENT_USER}" 2>/dev/null || true
  fi
  if systemctl is-enabled --quiet "code-server@${CURRENT_USER}" 2>/dev/null; then
    echo "Disabling systemd service: code-server@${CURRENT_USER}..."
    run_elevated systemctl disable "code-server@${CURRENT_USER}" 2>/dev/null || true
  fi
  if systemctl is-active --quiet "code-server" 2>/dev/null; then
    run_elevated systemctl stop code-server 2>/dev/null || true
  fi
  if systemctl is-enabled --quiet "code-server" 2>/dev/null; then
    run_elevated systemctl disable code-server 2>/dev/null || true
  fi

  # Remove unit files if present
  run_elevated rm -f /etc/systemd/system/code-server*.service /lib/systemd/system/code-server*.service 2>/dev/null || true
  rm -f "${HOME}/.config/systemd/user/code-server*.service" 2>/dev/null || true
  run_elevated systemctl daemon-reload 2>/dev/null || true
fi

# 3. Detect and uninstall via package manager / binary removal
echo "[3/4] Removing code-server installation..."
REMOVED_ANY=false

# Method: Debian / Ubuntu (dpkg / apt)
if command -v dpkg >/dev/null 2>&1 && dpkg -s code-server >/dev/null 2>&1; then
  echo "Detected dpkg/apt installation. Removing package..."
  if [[ "$PURGE_DATA" == true ]]; then
    run_elevated apt-get remove --purge -y code-server
  else
    run_elevated apt-get remove -y code-server
  fi
  REMOVED_ANY=true
fi

# Method: RHEL / Fedora / CentOS (rpm / dnf / yum)
if command -v rpm >/dev/null 2>&1 && rpm -q code-server >/dev/null 2>&1; then
  echo "Detected rpm installation. Removing package..."
  if command -v dnf >/dev/null 2>&1; then
    run_elevated dnf remove -y code-server
  elif command -v yum >/dev/null 2>&1; then
    run_elevated yum remove -y code-server
  else
    run_elevated rpm -e code-server
  fi
  REMOVED_ANY=true
fi

# Method: Arch Linux (pacman)
if command -v pacman >/dev/null 2>&1 && pacman -Qi code-server >/dev/null 2>&1; then
  echo "Detected pacman installation. Removing package..."
  run_elevated pacman -R --noconfirm code-server
  REMOVED_ANY=true
fi

# Method: macOS Homebrew
if command -v brew >/dev/null 2>&1 && brew list code-server >/dev/null 2>&1; then
  echo "Detected Homebrew installation. Removing formula..."
  brew uninstall code-server
  REMOVED_ANY=true
fi

# Method: Global npm package
if command -v npm >/dev/null 2>&1 && npm list -g code-server >/dev/null 2>&1; then
  echo "Detected npm installation. Removing global package..."
  run_elevated npm uninstall -g code-server
  REMOVED_ANY=true
fi

# Method: Standalone directories & symlinks
STANDALONE_PATHS=(
  "${HOME}/.local/bin/code-server"
  "${HOME}/.local/lib/code-server*"
  "/usr/lib/code-server"
  "/usr/bin/code-server"
  "/usr/local/bin/code-server"
)

for p in "${STANDALONE_PATHS[@]}"; do
  # Expand glob if present
  for matched in $p; do
    if [[ -e "$matched" ]]; then
      echo "Removing standalone path: $matched"
      if [[ -w "$(dirname "$matched")" ]]; then
        rm -rf "$matched"
      else
        run_elevated rm -rf "$matched"
      fi
      REMOVED_ANY=true
    fi
  done
done

if [[ "$REMOVED_ANY" == false ]]; then
  echo "Notice: No existing code-server installation package or binary was detected."
fi

# 4. Clean up user data and configurations if --purge requested
echo "[4/4] Configuration and user data cleanup..."
if [[ "$PURGE_DATA" == true ]]; then
  echo "Purging configuration and data directories..."
  rm -rf "${HOME}/.config/code-server"
  rm -rf "${HOME}/.local/share/code-server"
  run_elevated rm -rf /etc/code-server 2>/dev/null || true
  echo "All settings, extensions, and user data have been deleted."
else
  echo "Skipped configuration cleanup. (Use --purge if you wish to delete ~/.config/code-server and ~/.local/share/code-server)"
fi

echo "=========================================="
echo " code-server uninstallation complete!"
echo "=========================================="
