#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE="actions-runner-linux-arm64-2.337.0.tar.gz"
ARCHIVE_PATH="${SCRIPT_DIR}/${PACKAGE}"

# Detect if user passed env vars explicitly
RUNNER_NAME_FROM_ENV="${RUNNER_NAME:-}"
TOKEN_FROM_ENV="${TOKEN:-}"

# Defaults
TOKEN="${TOKEN:-APU474NU4QE6APBVNNVBUYLKZ5LG6}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
LABELS="${LABELS:-infra,infra-arm64,self-hosted,arm64,taskforge-runner}"
REPO_URL="${REPO_URL:-https://github.com/ShubhamBhavsar101/Taskforge}"
RECONFIG="${RECONFIG:-false}"

HAS_CLI_ARGS=false
if [ $# -gt 0 ]; then
  HAS_CLI_ARGS=true
fi

# ==============================================================================
# MODE 1: No arguments & no specific runner requested -> Launch ALL available runners
# ==============================================================================
if [ "${HAS_CLI_ARGS}" = "false" ] && [ -z "${RUNNER_NAME_FROM_ENV}" ] && [ -z "${TOKEN_FROM_ENV}" ]; then
  echo "==> No specific runner arguments provided."
  echo "==> Searching for configured runners in ${SCRIPT_DIR}..."

  RUNNER_DIRS=()
  for dir in "${SCRIPT_DIR}"/actions-runner*; do
    if [ -d "${dir}" ] && [ -f "${dir}/.runner" ] && [ -f "${dir}/run.sh" ]; then
      RUNNER_DIRS+=("${dir}")
    fi
  done

  if [ ${#RUNNER_DIRS[@]} -eq 0 ]; then
    echo "No configured runners found in ${SCRIPT_DIR}."
    echo "Configure a new runner with: $0 --name <RUNNER_NAME> --token <TOKEN>"
    exit 1
  fi

  echo "==> Found ${#RUNNER_DIRS[@]} configured runner(s):"
  for rdir in "${RUNNER_DIRS[@]}"; do
    echo "    • $(basename "${rdir}")"
  done

  # Trap Ctrl+C (SIGINT) and SIGTERM to stop all child runners cleanly
  PIDS=()
  cleanup() {
    echo ""
    echo "==> Stopping all active runners..."
    trap - SIGINT SIGTERM EXIT
    for pid in "${PIDS[@]:-}"; do
      if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
        kill -TERM "${pid}" 2>/dev/null || true
      fi
    done
    wait 2>/dev/null || true
    echo "==> All runners stopped."
    exit 0
  }
  trap cleanup SIGINT SIGTERM

  echo "==> Starting all ${#RUNNER_DIRS[@]} runners in parallel..."
  for rdir in "${RUNNER_DIRS[@]}"; do
    rname="$(basename "${rdir}")"
    (
      cd "${rdir}"
      ./run.sh 2>&1 | while IFS= read -r line; do
        printf "[%s] %s\n" "${rname}" "${line}"
      done
    ) &
    PIDS+=($!)
  done

  # Wait for all background runner processes
  wait
  exit 0
fi

# ==============================================================================
# MODE 2: Specific runner configuration or targeted execution
# ==============================================================================

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --token=*)
      TOKEN="${1#*=}"
      shift
      ;;
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --name=*)
      RUNNER_NAME="${1#*=}"
      shift
      ;;
    --name)
      RUNNER_NAME="$2"
      shift 2
      ;;
    --url=*)
      REPO_URL="${1#*=}"
      shift
      ;;
    --url)
      REPO_URL="$2"
      shift 2
      ;;
    --labels=*)
      LABELS="${1#*=}"
      shift
      ;;
    --labels)
      LABELS="$2"
      shift 2
      ;;
    --reconfig)
      RECONFIG="true"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo ""
      echo "When run with NO arguments, all available configured runners will start simultaneously."
      echo ""
      echo "Options for single runner setup:"
      echo "  --token <token>       GitHub Runner registration token"
      echo "  --name <name>         Unique name for this runner (default: $(hostname))"
      echo "  --url <url>           Repository URL (default: ${REPO_URL})"
      echo "  --labels <labels>     Comma-separated labels"
      echo "  --reconfig            Reset and re-register runner config"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      shift
      ;;
  esac
done

# Reuse existing archive if already downloaded in old folder
if [ ! -f "${ARCHIVE_PATH}" ] && [ -f "${SCRIPT_DIR}/actions-runner/${PACKAGE}" ]; then
  cp "${SCRIPT_DIR}/actions-runner/${PACKAGE}" "${ARCHIVE_PATH}"
fi

# Download runner package only if not already cached
if [ ! -f "${ARCHIVE_PATH}" ]; then
  echo "==> Downloading runner package to ${ARCHIVE_PATH}..."
  curl -o "${ARCHIVE_PATH}" -L "https://github.com/actions/runner/releases/download/v2.337.0/${PACKAGE}"
fi

# Dedicated isolated directory for this runner
RUNNER_DIR="${SCRIPT_DIR}/actions-runner-${RUNNER_NAME}"
mkdir -p "${RUNNER_DIR}" && cd "${RUNNER_DIR}"

# Extract and install dependencies if not yet unpacked in this folder
if [ ! -f "config.sh" ]; then
  echo "==> Extracting runner package into ${RUNNER_DIR}..."
  tar xzf "${ARCHIVE_PATH}"
  sudo ./bin/installdependencies.sh
fi

# Reset local configuration if --reconfig flag or RECONFIG=true is passed
if [ "${RECONFIG}" = "true" ]; then
  echo "==> Reconfiguration requested. Resetting local config for ${RUNNER_NAME}..."
  rm -f .runner .credentials*
fi

# Only configure if not already configured
if [ ! -f ".runner" ]; then
  echo "==> Registering runner '${RUNNER_NAME}' with GitHub..."
  ./config.sh --url "${REPO_URL}" \
              --token "${TOKEN}" \
              --name "${RUNNER_NAME}" \
              --labels "${LABELS}" \
              --unattended \
              --replace
else
  echo "==> Runner '${RUNNER_NAME}' already configured. Starting listener..."
fi

# Run the runner
./run.sh
