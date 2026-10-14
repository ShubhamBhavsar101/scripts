#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE="actions-runner-linux-arm64-2.337.0.tar.gz"
ARCHIVE_PATH="${SCRIPT_DIR}/${PACKAGE}"

# Environment configuration
TOKEN="${TOKEN:-APU474NU4QE6APBVNNVBUYLKZ5LG6}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
LABELS="${LABELS:-infra,infra-arm64,self-hosted,arm64,taskforge-runner}"
REPO_URL="${REPO_URL:-https://github.com/ShubhamBhavsar101/Taskforge}"
RECONFIG="${RECONFIG:-false}"

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
if [ "${RECONFIG}" = "true" ] || [ "${1:-}" = "--reconfig" ]; then
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
