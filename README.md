# Scripts

A collection of useful utility and automation scripts.

## Scripts Index

- [code-server/codeserver.sh](code-server/codeserver.sh): Automatically installs and starts [code-server](https://github.com/coder/code-server) on port `9090` targeting `/root` by default, with support for overriding the workspace path, port, and authentication flags via arguments.
- [code-server/uninstall.sh](code-server/uninstall.sh): Stops running instances, tears down systemd services, detects installation method (apt, dnf, pacman, brew, npm, standalone) to cleanly uninstall `code-server`, with optional `--purge` for user settings and cached data.
- [common/setup-config.sh](common/setup-config.sh): Automates setup of Git `git acp` (one-step add, commit, and push with auto-upstream) and Kubernetes `alias k='kubectl'` (with dynamic completion) in `~/.bashrc`, `~/.bash_aliases`, and `~/.zshrc`.
- [kind/install-docker.sh](kind/install-docker.sh): Downloads and installs official Docker CE via the official convenience script, enables the systemd service, and adds the current user to the `docker` group.
- [kind/install-kind.sh](kind/install-kind.sh): Downloads and installs the latest versions of [kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker), [kubectl](https://kubernetes.io/docs/tasks/tools/), and [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/) for the host architecture.
- [multipass/setup-ssd.sh](multipass/setup-ssd.sh): Automates configuring Canonical Multipass to store VM disks and data on an external SSD on macOS, fixing permissions, TCC errors, and corrupted daemon locks.
- [multipass/restore-internal.sh](multipass/restore-internal.sh): Reverts Multipass storage back to the Mac internal SSD, leaving external SSD VM data untouched for future use.
- [ssh/quick-setup.sh](ssh/quick-setup.sh): Minimal standalone one-liner script to create `~/.ssh`, append your public key, set `700`/`600` permissions, and start the SSH service.
- [ssh/setup-ssh.sh](ssh/setup-ssh.sh): Configures authorized SSH keys, enforces secure permissions (`700`/`600`), installs OpenSSH server if missing, and ensures the SSH daemon is active on target machines.

---

### `common/setup-config.sh`

#### Features
- **Git User Setup**: Configures Git `user.name` and `user.email`.
- **Git `git acp`**: Configures `git acp "<message>"` (`git add -A && git commit -m "$*" && git push`).
- **Kubernetes Alias**: Sets `alias k='kubectl'` in `~/.bash_aliases`.
- **Cross-Shell**: Updates `~/.bash_aliases` (sourced by `~/.bashrc`) and `~/.zshrc` safely and idempotently.

#### Usage

```bash
# Run setup script with defaults
./common/setup-config.sh

# Configure only git settings
./common/setup-config.sh --git-only

# Configure only shell aliases
./common/setup-config.sh --shell-only
```


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

### `ssh/setup-ssh.sh`

#### Features
- **Instant Access**: Embedded with your default public key to enable SSH login with zero configuration on ephemeral cloud machines.
- **Idempotent Key Addition**: Appends the key safely into `~/.ssh/authorized_keys` without creating duplicate entries.
- **Strict Permissions**: Enforces `chmod 700 ~/.ssh` and `chmod 600 ~/.ssh/authorized_keys` required by OpenSSH.
- **Auto-Installs Daemon**: Detects if `sshd` is absent and installs `openssh-server` using `apt`, `dnf`, `yum`, `pacman`, or `apk`.
- **Starts & Enables Service**: Automatically starts and enables `ssh`/`sshd` via `systemctl` or `service`.
- **Custom Keys & GitHub Sync**: Supports custom key strings via argument/`-k` or pulling public keys dynamically from any GitHub user via `-g` / `--github`.
- **Connection Helper**: Resolves and prints the machine's primary IP address and exact `ssh` command.

#### Usage

```bash
# Default: Installs your embedded default public key
./ssh/setup-ssh.sh

# Pass custom public key
./ssh/setup-ssh.sh "ssh-ed25519 AAAA... user@local"

# Authorize keys from a GitHub account
./ssh/setup-ssh.sh --github ShubhamBhavsar101
```

#### One-Liner Execution via curl

Run directly on the target machine:

```bash
curl -fsSL https://raw.githubusercontent.com/ShubhamBhavsar101/scripts/main/ssh/setup-ssh.sh | bash
```

Or with a GitHub username:

```bash
curl -fsSL https://raw.githubusercontent.com/ShubhamBhavsar101/scripts/main/ssh/setup-ssh.sh | bash -s -- --github ShubhamBhavsar101
```

---

### `ssh/quick-setup.sh`

#### Usage

Execute directly on any target machine to instantly authorize your Mac key and enable SSH:

```bash
curl -fsSL https://raw.githubusercontent.com/ShubhamBhavsar101/scripts/main/ssh/quick-setup.sh | bash
```

Or run directly:

```bash
./ssh/quick-setup.sh
```

---

&copy; 2026 Developed by Shubham Bhavsar.
