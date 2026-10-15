# Common Command & Environment Configuration

Lightweight setup script for Git user identity, `git acp` shortcut, and `alias k='kubectl'`.

---

## Features

- **Git User Setup**:
  - Automatically configures `user.name` and `user.email`.
- **Git `acp` Shortcut**:
  - `git acp "<message>"`: One-step command to stage all changes (`git add -A`), commit with message, and push to remote (`git push` with automatic upstream fallback).
- **Kubernetes Alias**:
  - `alias k='kubectl'` in `~/.bash_aliases` (and `~/.zshrc`).
- **Multi-Shell Compatibility**:
  - Works with Bash (`~/.bashrc`, `~/.bash_aliases`) and Zsh (`~/.zshrc`).
  - Safe & idempotent: updates existing blocks cleanly without duplicating lines.

---

## Usage

### Run Configuration

```bash
# Make script executable
chmod +x ./common/setup-config.sh

# Run setup (configures git user, git acp, and k=kubectl)
./common/setup-config.sh
```

### Options

```bash
# Configure only Git settings
./common/setup-config.sh --git-only

# Configure only Shell alias k=kubectl
./common/setup-config.sh --shell-only

# Specify Git user name and email explicitly
./common/setup-config.sh --name "Your Name" --email "your.email@example.com"
```

### Apply in Current Terminal

After running the script, activate the alias in your active shell:

```bash
source ~/.bashrc
# or
source ~/.bash_aliases
```

---

&copy; 2026 Developed by Shubham Bhavsar.
