#!/usr/bin/env bash
# ==============================================================================
# Multipass External SSD Automated Setup & Recovery Script
# Developed by Shubham Bhavsar
#
# Solves all common macOS Multipass external storage issues:
# 1. Moves Multipass VM storage (/var/root/Library/Application Support/multipassd) to external SSD
# 2. Enables POSIX volume ownership on external APFS drive
# 3. Fixes macOS TCC "Operation not permitted" on ssh-keys & QEMU image files
# 4. Cleans up orphaned QEMU & hung daemon processes
# 5. Resets corrupted bridged-network locks
# 6. Clears bad partial image caches
# ==============================================================================

set -euo pipefail

# --- Color formatting ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[multipass-ssd]${NC} $1"; }
ok()    { echo -e "${GREEN}[multipass-ssd]${NC} $1"; }
warn()  { echo -e "${YELLOW}[multipass-ssd]${NC} $1"; }
error() { echo -e "${RED}[multipass-ssd]${NC} $1" >&2; }

# --- OS Check ---
if [[ "$(uname -s)" != "Darwin" ]]; then
  error "This script is designed for macOS only."
  exit 1
fi

# --- Target SSD Volume ---
SSD_VOLUME="${1:-/Volumes/ShubhEVM}"

# Normalize path (strip trailing slash)
SSD_VOLUME="${SSD_VOLUME%/}"

info "Target SSD Volume: ${SSD_VOLUME}"

if [[ ! -d "${SSD_VOLUME}" ]]; then
  error "Mount point '${SSD_VOLUME}' does not exist! Please ensure your external SSD is connected and mounted."
  echo "Available volumes in /Volumes:"
  ls -1 /Volumes | sed 's/^/  - /'
  exit 1
fi

SSD_MULTIPASS_DIR="${SSD_VOLUME}/multipassd"
DEFAULT_MULTIPASS_DIR="/var/root/Library/Application Support/multipassd"

# --- Elevation check ---
if [[ $EUID -ne 0 ]]; then
  info "Administrator privileges are required to configure daemon symlinks and disk permissions."
  info "Re-running script with sudo..."
  exec sudo "$0" "$@"
fi

# --- Step 1: Enable POSIX disk ownership on external SSD ---
info "Step 1/6: Ensuring disk ownership is enabled on ${SSD_VOLUME}..."
diskutil enableOwnership "${SSD_VOLUME}" >/dev/null 2>&1 || true
ok "Ownership enabled on external drive."

# --- Step 2: Stop hung processes and unload daemon ---
info "Step 2/6: Stopping Multipass services and cleaning orphaned processes..."
killall -9 qemu-system-aarch64 2>/dev/null || true
killall -9 multipassd 2>/dev/null || true
launchctl bootout system/com.canonical.multipassd 2>/dev/null || true
sleep 1
ok "Processes stopped."

# --- Step 3: Prepare SSD directory structure and permissions ---
info "Step 3/6: Setting up directory structure on SSD..."
mkdir -p "${SSD_MULTIPASS_DIR}/ssh-keys"
mkdir -p "${SSD_MULTIPASS_DIR}/qemu/vault"

# Remove macOS quarantine flags and ACLs that cause "Operation not permitted"
xattr -cr "${SSD_MULTIPASS_DIR}" 2>/dev/null || true
chmod -RN "${SSD_MULTIPASS_DIR}" 2>/dev/null || true
chmod -R 777 "${SSD_MULTIPASS_DIR}" 2>/dev/null || true
ok "Permissions and ssh-keys pre-created on ${SSD_MULTIPASS_DIR}."

# --- Step 4: Configure system symlink ---
info "Step 4/6: Linking default storage path to SSD..."
if [[ -L "${DEFAULT_MULTIPASS_DIR}" ]]; then
  CURRENT_TARGET="$(readlink "${DEFAULT_MULTIPASS_DIR}" || true)"
  if [[ "${CURRENT_TARGET}" == "${SSD_MULTIPASS_DIR}" ]]; then
    ok "Symlink already correctly points to ${SSD_MULTIPASS_DIR}."
  else
    warn "Symlink points to '${CURRENT_TARGET}'. Updating to ${SSD_MULTIPASS_DIR}..."
    rm -f "${DEFAULT_MULTIPASS_DIR}"
    ln -s "${SSD_MULTIPASS_DIR}" "${DEFAULT_MULTIPASS_DIR}"
    ok "Symlink updated."
  fi
elif [[ -d "${DEFAULT_MULTIPASS_DIR}" ]]; then
  # Migrate any existing instances if present
  if [[ $(ls -A "${DEFAULT_MULTIPASS_DIR}" 2>/dev/null | wc -l) -gt 0 ]]; then
    info "Existing data found in ${DEFAULT_MULTIPASS_DIR}. Syncing to SSD..."
    rsync -a "${DEFAULT_MULTIPASS_DIR}/" "${SSD_MULTIPASS_DIR}/"
  fi
  rm -rf "${DEFAULT_MULTIPASS_DIR}"
  ln -s "${SSD_MULTIPASS_DIR}" "${DEFAULT_MULTIPASS_DIR}"
  ok "Default folder moved and symlinked to SSD."
else
  mkdir -p "/var/root/Library/Application Support"
  ln -s "${SSD_MULTIPASS_DIR}" "${DEFAULT_MULTIPASS_DIR}"
  ok "Symlink created."
fi

# --- Step 5: Clean up corrupted image downloads & broken bridge configs ---
info "Step 5/6: Flushing bad image cache & resetting potential bridge locks..."
rm -rf /var/root/Library/Caches/multipassd/qemu/vault/images/* 2>/dev/null || true

# If vm instances json contains broken bridged settings, clean them
VM_JSON="${SSD_MULTIPASS_DIR}/qemu/multipassd-vm-instances.json"
if [[ -f "${VM_JSON}" ]]; then
  sed -i '' 's/"bridged_network":[[:space:]]*"[^"]*"/"bridged_network": ""/g' "${VM_JSON}" 2>/dev/null || true
fi
ok "Cache and configs sanitized."

# --- Step 6: Start multipassd daemon ---
info "Step 6/6: Starting Multipass daemon..."
launchctl bootstrap system /Library/LaunchDaemons/com.canonical.multipassd.plist 2>/dev/null || \
launchctl kickstart -k system/com.canonical.multipassd

sleep 2

# Verify CLI connection
if multipass list >/dev/null 2>&1; then
  echo ""
  ok "=========================================================="
  ok "  Multipass is running successfully on your external SSD! "
  ok "=========================================================="
  echo ""
  multipass list
else
  warn "Multipass daemon started, but CLI handshake is still pending."
  warn "If 'Operation not permitted' occurs, ensure Full Disk Access is granted in macOS:"
  echo "  1. System Settings -> Privacy & Security -> Full Disk Access"
  echo "  2. Ensure the following binaries are toggled ON:"
  echo "     - /Library/Application Support/com.canonical.multipass/bin/multipassd"
  echo "     - /Library/Application Support/com.canonical.multipass/bin/qemu-system-aarch64"
  echo "     - Terminal (or your active shell/terminal app)"
fi
