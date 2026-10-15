#!/usr/bin/env bash
# ==============================================================================
# Multipass Restore Internal Storage Script
# Developed by Shubham Bhavsar
#
# Reverts Multipass storage back to macOS internal SSD:
# 1. Gracefully stops running VMs and daemon processes
# 2. Removes the external SSD symlink
# 3. Creates a fresh internal storage directory (/var/root/Library/Application Support/multipassd)
# 4. Leaves data on the external SSD untouched for future use
# 5. Restarts the daemon and verifies connection
# ==============================================================================

set -euo pipefail

# --- Color formatting ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[multipass-internal]${NC} $1"; }
ok()    { echo -e "${GREEN}[multipass-internal]${NC} $1"; }
warn()  { echo -e "${YELLOW}[multipass-internal]${NC} $1"; }
error() { echo -e "${RED}[multipass-internal]${NC} $1" >&2; }

# --- OS Check ---
if [[ "$(uname -s)" != "Darwin" ]]; then
  error "This script is designed for macOS only."
  exit 1
fi

DEFAULT_MULTIPASS_DIR="/var/root/Library/Application Support/multipassd"

# --- Elevation check ---
if [[ $EUID -ne 0 ]]; then
  info "Administrator privileges are required to configure system directories."
  info "Re-running script with sudo..."
  exec sudo "$0" "$@"
fi

TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"

# --- Step 1: Stop services and kill lingering processes ---
info "Step 1/4: Stopping Multipass services..."
sudo -u "${TARGET_USER}" multipass stop --all 2>/dev/null || true
launchctl bootout system/com.canonical.multipassd 2>/dev/null || true
killall -9 qemu-system-aarch64 2>/dev/null || true
killall -9 multipassd 2>/dev/null || true
sleep 1
ok "Services stopped."

# --- Step 2: Remove symlink and create clean internal directory ---
info "Step 2/4: Reverting storage to Mac internal drive..."
if [[ -L "${DEFAULT_MULTIPASS_DIR}" ]]; then
  PREV_TARGET="$(readlink "${DEFAULT_MULTIPASS_DIR}" || true)"
  rm -f "${DEFAULT_MULTIPASS_DIR}"
  ok "Removed symlink pointing to '${PREV_TARGET}'."
elif [[ -d "${DEFAULT_MULTIPASS_DIR}" ]]; then
  ok "Default path is already a directory on the internal drive."
fi

mkdir -p "${DEFAULT_MULTIPASS_DIR}"
chmod 755 "${DEFAULT_MULTIPASS_DIR}"
ok "Created fresh internal directory at ${DEFAULT_MULTIPASS_DIR}."

# --- Step 3: Flush temporary cache ---
info "Step 3/4: Flushing image cache..."
rm -rf /var/root/Library/Caches/multipassd/qemu/vault/images/* 2>/dev/null || true
ok "Cache flushed."

# --- Step 4: Restart multipassd daemon ---
info "Step 4/4: Starting Multipass daemon..."
launchctl bootstrap system /Library/LaunchDaemons/com.canonical.multipassd.plist 2>/dev/null || \
launchctl kickstart -k system/com.canonical.multipassd

# --- Verify CLI connection with retry loop ---
info "Verifying Multipass connection..."
CONNECTED=false
for i in {1..20}; do
  if sudo -u "${TARGET_USER}" multipass list >/dev/null 2>&1; then
    CONNECTED=true
    break
  fi
  printf "."
  sleep 1
done
echo ""

if [[ "${CONNECTED}" == "true" ]]; then
  echo ""
  ok "=========================================================="
  ok "  ✅ Multipass restored to Mac Internal SSD successfully! "
  ok "  Data on external SSD remains saved and untouched.       "
  ok "=========================================================="
  echo ""
  sudo -u "${TARGET_USER}" multipass list
else
  warn "Multipass daemon started, but CLI handshake is still pending."
  warn "You can verify manually by running: multipass list"
fi
