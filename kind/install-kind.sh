#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Official installation method for kind (Kubernetes in Docker) and kubectl
# Sources:
# - kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries
# - kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
# ==============================================================================

ARCH="$(uname -m)"
if [ "${ARCH}" != "x86_64" ] && [ "${ARCH}" != "aarch64" ]; then
    echo "Error: Unsupported architecture: ${ARCH}" >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# 1. Install kind
# ------------------------------------------------------------------------------
# Dynamically fetch the latest release version, with fallback
KIND_VERSION="${KIND_VERSION:-$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/kubernetes-sigs/kind/releases/latest | sed 's#.*/##')}"
KIND_VERSION="${KIND_VERSION:-v0.33.0}"

echo "Installing kind ${KIND_VERSION} (arch: ${ARCH})..."

# Commands directly from kind official documentation:
[ "${ARCH}" = "x86_64" ] && curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
[ "${ARCH}" = "aarch64" ] && curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-arm64"

chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# ------------------------------------------------------------------------------
# 2. Install kubectl
# ------------------------------------------------------------------------------
# Dynamically fetch the latest release version, with fallback
KUBECTL_VERSION="${KUBECTL_VERSION:-$(curl -fsSL https://dl.k8s.io/release/stable.txt)}"
KUBECTL_VERSION="${KUBECTL_VERSION:-v1.37.1}"

echo "Installing kubectl ${KUBECTL_VERSION} (arch: ${ARCH})..."

# Commands directly from Kubernetes official documentation:
[ "${ARCH}" = "x86_64" ] && curl -Lo ./kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
[ "${ARCH}" = "aarch64" ] && curl -Lo ./kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/arm64/kubectl"

chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# ------------------------------------------------------------------------------
# Verify installations
# ------------------------------------------------------------------------------
echo "==> Verifying installations:"
kind version
kubectl version --client
