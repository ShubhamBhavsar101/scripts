# Scripts

A collection of useful utility and automation scripts.

## Scripts Index

- [code-server/codeserver.sh](code-server/codeserver.sh): Automatically installs and starts [code-server](https://github.com/coder/code-server) on port `9090` targeting `/root` by default, with support for overriding the workspace path, port, and authentication flags via arguments.
- [code-server/uninstall.sh](code-server/uninstall.sh): Stops running instances, tears down systemd services, detects installation method (apt, dnf, pacman, brew, npm, standalone) to cleanly uninstall `code-server`, with optional `--purge` for user settings and cached data.

---

### `code-server/codeserver.sh`

#### Features
- **Automatic Installation**: Detects if `code-server` is present; if not, automatically downloads and installs the latest version using `curl`/`wget`.
- **Default Port**: Listens on port `9090` bound to `0.0.0.0` (remote-accessible).
- **Default Workspace**: Opens `/root` by default (creates the path if it does not already exist).
- **No Password Prompt**: Runs with `--auth none` by default so no password is required.
- **Flexible Path Override**: Override the target workspace directory via positional argument or `-d` / `--dir` flag.
- **Customizable**: Allows overriding port (`-p` / `--port`), host/bind address (`-b` / `--bind`), and auth options (`--auth password`).

#### Usage

```bash
# Default: Runs on /root on port 9090 (no password required)
./code-server/codeserver.sh

# Override workspace path via positional argument
./code-server/codeserver.sh /home/ubuntu/workspace

# Override workspace path via --dir flag
./code-server/codeserver.sh --dir /var/www/html

# Custom port
./code-server/codeserver.sh --port 8080 /my/project

# Enable password authentication if desired
./code-server/codeserver.sh --auth password /root
```

#### One-Liner Execution via curl

```bash
curl -fsSL https://raw.githubusercontent.com/ShubhamBhavsar101/scripts/main/code-server/codeserver.sh | bash -s -- /custom/path
```

---

### `code-server/uninstall.sh`

#### Features
- **Process Cleanup**: Kills active `code-server` processes.
- **Service Teardown**: Stops and disables systemd unit files if present.
- **Auto Detection**: Detects package manager (`apt`, `dnf`, `yum`, `pacman`, `brew`, `npm`) or standalone binaries in `~/.local` and `/usr/lib`.
- **Optional Purge**: Supports `--purge` to delete configuration and extensions (`~/.config/code-server` and `~/.local/share/code-server`).

#### Usage

```bash
# Standard uninstall (removes binaries & services, preserves configs)
./code-server/uninstall.sh

# Full purge (removes binaries, systemd units, configs, and extensions)
./code-server/uninstall.sh --purge

# Non-interactive full purge
./code-server/uninstall.sh -y --purge
```

#### One-Liner Execution via curl

```bash
curl -fsSL https://raw.githubusercontent.com/ShubhamBhavsar101/scripts/main/code-server/uninstall.sh | bash -s -- -y --purge
```

---

&copy; 2026 Developed by Shubham Bhavsar. Runs 100% locally.
