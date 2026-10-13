#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Official installation method for kind (Kubernetes in Docker)
# Source: https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries
# ==============================================================================

# Dynamically fetch the latest release version, with fallback
KIND_VERSION="${KIND_VERSION:-$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/kubernetes-sigs/kind/releases/latest | sed 's#.*/##')}"
KIND_VERSION="${KIND_VERSION:-v0.33.0}"

echo "Installing kind ${KIND_VERSION} (arch: $(uname -m))..."

# Commands directly from kind official documentation:
[ "$(uname -m)" = "x86_64" ] && curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
[ "$(uname -m)" = "aarch64" ] && curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-arm64"

chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify installation
kind version
