#!/usr/bin/env bash
set -euo pipefail

# Create a folder
mkdir -p actions-runner && cd actions-runner

PACKAGE="actions-runner-linux-arm64-2.337.0.tar.gz"

# Download only if not already downloaded
if [ ! -f "${PACKAGE}" ]; then
  echo "==> Downloading runner package..."
  curl -o "${PACKAGE}" -L "https://github.com/actions/runner/releases/download/v2.337.0/${PACKAGE}"
fi

# Extract and install dependencies only if not already extracted
if [ ! -f "config.sh" ]; then
  echo "==> Extracting runner package..."
  tar xzf "./${PACKAGE}"
  sudo ./bin/installdependencies.sh
fi

TOKEN="${TOKEN:-APU474NU4QE6APBVNNVBUYLKZ5LG6}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
LABELS="${LABELS:-infra,infra-arm64,self-hosted,arm64,taskforge-runner}"
REPO_URL="${REPO_URL:-https://github.com/ShubhamBhavsar101/Taskforge}"
RECONFIG="${RECONFIG:-false}"

# Reset local configuration if --reconfig flag or RECONFIG=true is passed
if [ "${RECONFIG}" = "true" ] || [ "${1:-}" = "--reconfig" ]; then
  echo "==> Reconfiguration requested. Resetting local config..."
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
  echo "==> Runner already configured. Starting listener..."
fi

# Last step, run it!
./run.sh
