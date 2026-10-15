# Multipass on External SSD — Setup & Operations Guide

Run your Multipass Ubuntu instances entirely from an external SSD to save internal Mac disk space, complete with automated setup and safe disconnect workflows.

---

## Quick Setup

Run the automated setup script pointing to your mounted external SSD volume (defaults to `/Volumes/ShubhEVM` if omitted):

```bash
sudo ./setup-ssd.sh /Volumes/YourSSDName
```

### What the script automates:
1. **POSIX Ownership**: Runs `diskutil enableOwnership` on the drive so the daemon can manage VM images.
2. **Permission Sanitization**: Pre-creates `/Volumes/<Drive>/multipassd/ssh-keys` with full access and removes quarantine flags (`xattr -cr`, `chmod -RN`) to prevent macOS TCC *"Operation not permitted"* crashes.
3. **Storage Symlink**: Moves and symlinks `/var/root/Library/Application Support/multipassd` to your external SSD.
4. **Cache & Process Cleanup**: Terminates orphaned QEMU processes and cleans broken image caches and bridge locks.
5. **Daemon Launch**: Kicks off `multipassd` cleanly and validates connectivity.

---

## Prerequisites (macOS Full Disk Access)

Because macOS sandboxes external drives, grant Full Disk Access to the Multipass binaries:
1. Go to **System Settings** → **Privacy & Security** → **Full Disk Access**.
2. Add and toggle **ON**:
   - `/Library/Application Support/com.canonical.multipass/bin/multipassd`
   - `/Library/Application Support/com.canonical.multipass/bin/qemu-system-aarch64`
   - **Terminal** (or your active terminal app)

---

## Safe Eject & Resume Workflow

To prevent filesystem corruption when unplugging your SSD, add these helper functions to your `~/.zshrc`:

```bash
# Safely stop VMs, kill daemons, and eject SSD
multipass-eject() {
  echo "Stopping all Multipass VMs..."
  multipass stop --all 2>/dev/null

  echo "Stopping Multipass daemon & QEMU..."
  sudo launchctl bootout system/com.canonical.multipassd 2>/dev/null
  sudo pkill -9 -f "qemu-system-aarch64" 2>/dev/null
  sudo pkill -9 -f "multipassd" 2>/dev/null
  sleep 1

  echo "Ejecting ShubhEVM..."
  if diskutil eject /Volumes/ShubhEVM; then
    echo "✅ Safe to disconnect your SSD!"
  else
    echo "⚠️ Failed to unmount ShubhEVM. Please check open files before pulling cable."
  fi
}

# Resume Multipass after reconnecting SSD
multipass-resume() {
  if [ ! -d "/Volumes/ShubhEVM/multipassd" ]; then
    echo "❌ ShubhEVM not detected! Please plug in the SSD first."
    return 1
  fi
  echo "Starting Multipass daemon..."
  sudo launchctl bootstrap system /Library/LaunchDaemons/com.canonical.multipassd.plist 2>/dev/null || sudo launchctl kickstart -k system/com.canonical.multipassd
  sleep 2
  multipass list
  echo "✅ Multipass is ready!"
}
```

### Usage
- Before unplugging: `multipass-eject`
- After plugging back in: `multipass-resume`

---

© 2026 Multipass External SSD Tools. Developed by Shubham Bhavsar. Runs 100% locally.
