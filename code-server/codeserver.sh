#!/usr/bin/env bash
#
# codeserver.sh - Install and run code-server
# Developed by Shubham Bhavsar
#
# Default workspace: /root
# Default port: 9090
#

set -euo pipefail

DEFAULT_DIR="/root"
DEFAULT_PORT="9090"
DEFAULT_HOST="0.0.0.0"

TARGET_DIR=""
PORT="${PORT:-$DEFAULT_PORT}"
HOST="${HOST:-$DEFAULT_HOST}"
EXTRA_ARGS=()

show_help() {
  cat << 'EOF'
Usage: codeserver.sh [OPTIONS] [WORKSPACE_DIR]

Installs code-server (if not already installed) and launches it.

Arguments:
  WORKSPACE_DIR           Target workspace directory (default: /root)

Options:
  -d, --dir DIR           Target workspace directory (default: /root)
  -p, --port PORT         Port to bind code-server to (default: 9090)
  -b, --bind HOST         Host/IP to bind to (default: 0.0.0.0)
      --auth TYPE         Authentication type (e.g. password, none)
  -h, --help              Show this help message and exit

Any unrecognized options will be passed directly through to code-server.

Examples:
  ./codeserver.sh                           # Runs on /root:9090
  ./codeserver.sh /home/ubuntu/projects     # Runs on /home/ubuntu/projects:9090
  ./codeserver.sh --port 8080 /var/www      # Runs on /var/www:8080
  ./codeserver.sh --auth none /workspace    # Disables password auth
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -d|--dir)
      if [[ -n "${2:-}" ]]; then
        TARGET_DIR="$2"
        shift 2
      else
        echo "Error: --dir requires a path argument." >&2
        exit 1
      fi
      ;;
    -p|--port)
      if [[ -n "${2:-}" ]]; then
        PORT="$2"
        shift 2
      else
        echo "Error: --port requires a port argument." >&2
        exit 1
      fi
      ;;
    -b|--bind)
      if [[ -n "${2:-}" ]]; then
        HOST="$2"
        shift 2
      else
        echo "Error: --bind requires a host argument." >&2
        exit 1
      fi
      ;;
    --auth)
      if [[ -n "${2:-}" ]]; then
        EXTRA_ARGS+=("--auth" "$2")
        shift 2
      else
        echo "Error: --auth requires an argument (e.g., password, none)." >&2
        exit 1
      fi
      ;;
    -*)
      EXTRA_ARGS+=("$1")
      shift
      ;;
    *)
      if [[ -z "$TARGET_DIR" ]]; then
        TARGET_DIR="$1"
      else
        EXTRA_ARGS+=("$1")
      fi
      shift
      ;;
  esac
done

# Set default directory if not overridden
TARGET_DIR="${TARGET_DIR:-$DEFAULT_DIR}"

install_code_server() {
  if command -v code-server >/dev/null 2>&1; then
    echo "[codeserver] code-server is already installed: $(command -v code-server)"
    return 0
  fi

  echo "[codeserver] code-server not found. Installing..."

  if command -v curl >/dev/null 2>&1; then
    FETCH_CMD="curl -fsSL https://code-server.dev/install.sh"
  elif command -v wget >/dev/null 2>&1; then
    FETCH_CMD="wget -qO- https://code-server.dev/install.sh"
  else
    echo "Error: curl or wget is required to install code-server." >&2
    exit 1
  fi

  # Check if sudo is available and needed
  if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    echo "[codeserver] Running installer with sudo..."
    $FETCH_CMD | sudo sh
  else
    $FETCH_CMD | sh
  fi

  if ! command -v code-server >/dev/null 2>&1; then
    echo "Error: Failed to install code-server." >&2
    exit 1
  fi

  echo "[codeserver] Successfully installed code-server $(code-server --version | head -n 1)"
}

prepare_workspace() {
  if [[ ! -d "$TARGET_DIR" ]]; then
    echo "[codeserver] Workspace directory '$TARGET_DIR' does not exist. Creating..."
    mkdir -p "$TARGET_DIR" 2>/dev/null || {
      if command -v sudo >/dev/null 2>&1; then
        sudo mkdir -p "$TARGET_DIR"
      else
        echo "Error: Failed to create directory '$TARGET_DIR'." >&2
        exit 1
      fi
    }
  fi
}

start_code_server() {
  echo "=========================================="
  echo " Starting code-server"
  echo " Workspace : ${TARGET_DIR}"
  echo " Bind Addr : ${HOST}:${PORT}"
  echo "=========================================="

  exec code-server \
    --bind-addr "${HOST}:${PORT}" \
    "${EXTRA_ARGS[@]}" \
    "${TARGET_DIR}"
}

install_code_server
prepare_workspace
start_code_server
