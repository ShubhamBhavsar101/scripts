# Scripts

A collection of useful utility and automation scripts.

## Scripts Index

- [code-server/codeserver.sh](code-server/codeserver.sh): Automatically installs and starts [code-server](https://github.com/coder/code-server) on port `9090` targeting `/root` by default, with support for overriding the workspace path, port, and authentication flags via arguments.

---

### `code-server/codeserver.sh`

#### Features
- **Automatic Installation**: Detects if `code-server` is present; if not, automatically downloads and installs the latest version using `curl`/`wget`.
- **Default Port**: Listens on port `9090` bound to `0.0.0.0` (remote-accessible).
- **Default Workspace**: Opens `/root` by default (creates the path if it does not already exist).
- **Flexible Path Override**: Override the target workspace directory via positional argument or `-d` / `--dir` flag.
- **Customizable**: Allows overriding port (`-p` / `--port`), host/bind address (`-b` / `--bind`), and auth options (`--auth none`).

#### Usage

```bash
# Default: Runs on /root on port 9090
./code-server/codeserver.sh

# Override workspace path via positional argument
./code-server/codeserver.sh /home/ubuntu/workspace

# Override workspace path via --dir flag
./code-server/codeserver.sh --dir /var/www/html

# Custom port
./code-server/codeserver.sh --port 8080 /my/project

# Run without password authentication
./code-server/codeserver.sh --auth none /root
```

#### One-Liner Execution via curl

```bash
curl -fsSL https://raw.githubusercontent.com/ShubhamBhavsar101/scripts/main/code-server/codeserver.sh | bash -s -- /custom/path
```

---

&copy; 2026 Developed by Shubham Bhavsar. Runs 100% locally.
