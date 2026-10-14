#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Official installation script for Docker CE
# Source: https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script
# Script: https://get.docker.com
# ==============================================================================

echo "==> Downloading official Docker installation script..."
TMP_DOCKER_SH="$(mktemp -t get-docker-XXXXXX.sh)"
trap 'rm -f "${TMP_DOCKER_SH}"' EXIT

curl -fsSL https://get.docker.com -o "${TMP_DOCKER_SH}"

echo "==> Running official Docker installer..."
sudo sh "${TMP_DOCKER_SH}"

echo "==> Enabling and starting Docker service..."
sudo systemctl enable --now docker

CURRENT_USER="${SUDO_USER:-$(id -un)}"
echo "==> Adding user '${CURRENT_USER}' to the docker group..."
sudo usermod -aG docker "${CURRENT_USER}"

echo "==> Verifying Docker installation..."
docker --version
sudo docker info > /dev/null 2>&1 && echo "Docker daemon is active and running!"

echo "=========================================================="
echo "Docker installed successfully via official script."
echo "Run 'newgrp docker' or re-login if non-sudo docker access"
echo "is needed in your current terminal session."
echo "=========================================================="
