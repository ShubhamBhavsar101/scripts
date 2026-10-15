#!/usr/bin/env bash
# ==============================================================================
# Common Command & Environment Configuration Setup
# Developed by Shubham Bhavsar
#
# Configures:
# 1. Git user setup (user.name and user.email)
# 2. Git 'acp' alias (git add -A && git commit -m "$*" && git push)
# 3. Shell alias: k='kubectl' in ~/.bash_aliases (and ~/.zshrc)
# ==============================================================================

set -euo pipefail

# --- Color formatting ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[common-config]${NC} $1"; }
ok()    { echo -e "${GREEN}[common-config]${NC} $1"; }
warn()  { echo -e "${YELLOW}[common-config]${NC} $1"; }
error() { echo -e "${RED}[common-config]${NC} $1" >&2; }

# --- CLI Options & Defaults ---
CONFIGURE_GIT=true
CONFIGURE_SHELL=true
GIT_USER_NAME=""
GIT_USER_EMAIL=""

print_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Configures Git user setup, git acp alias, and shell alias k=kubectl.

Options:
  --git-only           Configure only Git user and acp alias
  --shell-only         Configure only Shell alias k=kubectl
  --name <NAME>        Set Git user.name (defaults to current or 'Shubham Bhavsar')
  --email <EMAIL>      Set Git user.email (defaults to current or 'shubhamcbhavsar198@gmail.com')
  -h, --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --git-only)
      CONFIGURE_GIT=true
      CONFIGURE_SHELL=false
      shift
      ;;
    --shell-only)
      CONFIGURE_GIT=false
      CONFIGURE_SHELL=true
      shift
      ;;
    --name)
      GIT_USER_NAME="$2"
      shift 2
      ;;
    --email)
      GIT_USER_EMAIL="$2"
      shift 2
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      print_help
      exit 1
      ;;
  esac
done

# --- Determine Target User and Home Directory ---
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
USER_HOME="$(eval echo "~${TARGET_USER}")"

info "Target user: ${TARGET_USER} (Home: ${USER_HOME})"

# ==============================================================================
# 1. Configure Git (User Setup & 'acp' Alias)
# ==============================================================================
if [[ "${CONFIGURE_GIT}" = true ]]; then
  info "Configuring Git user and 'acp' alias..."

  # Run git commands as TARGET_USER to ensure ~/.gitconfig has proper ownership
  run_git() {
    if [[ $EUID -eq 0 && "${TARGET_USER}" != "root" ]]; then
      sudo -u "${TARGET_USER}" git "$@"
    else
      git "$@"
    fi
  }

  # Ensure user.name and user.email are set
  CURRENT_GIT_NAME="$(run_git config --global user.name 2>/dev/null || true)"
  CURRENT_GIT_EMAIL="$(run_git config --global user.email 2>/dev/null || true)"

  TARGET_NAME="${GIT_USER_NAME:-${CURRENT_GIT_NAME:-Shubham Bhavsar}}"
  TARGET_EMAIL="${GIT_USER_EMAIL:-${CURRENT_GIT_EMAIL:-shubhamcbhavsar198@gmail.com}}"

  run_git config --global user.name "${TARGET_NAME}"
  run_git config --global user.email "${TARGET_EMAIL}"
  ok "Git user configured: ${TARGET_NAME} <${TARGET_EMAIL}>"

  # Git 'acp' alias: Add, Commit, Push in one command
  # Supports:
  #   git acp "commit message"
  #   git acp commit message without quotes
  # Automatically sets upstream to current branch if remote branch does not exist yet.
  ACP_CMD='!f() { if [ $# -eq 0 ]; then echo "Usage: git acp <commit-message>" >&2; return 1; fi; git add -A && git commit -m "$*" && (git push || git push -u origin $(git rev-parse --abbrev-ref HEAD 2>/dev/null)); }; f'
  run_git config --global alias.acp "${ACP_CMD}"
  ok "Configured 'git acp' alias"

  # Clean up any other extra git configs if previously added
  for extra_alias in st co cb br cm undo unstage lg; do
    run_git config --global --unset "alias.${extra_alias}" 2>/dev/null || true
  done
  for extra_setting in init.defaultBranch push.autoSetupRemote pull.rebase; do
    run_git config --global --unset "${extra_setting}" 2>/dev/null || true
  done
fi

# ==============================================================================
# 2. Configure Shell Alias (k='kubectl')
# ==============================================================================
if [[ "${CONFIGURE_SHELL}" = true ]]; then
  info "Configuring shell alias (k=kubectl)..."

  ALIAS_START_MARKER="# >>> common-aliases >>>"
  ALIAS_END_MARKER="# <<< common-aliases <<<"

  COMMON_ALIAS_BLOCK=$(cat <<'EOF'
# >>> common-aliases >>>
# Managed by scripts/common/setup-config.sh
alias k='kubectl'
# <<< common-aliases <<<
EOF
)

  apply_aliases_to_file() {
    local target_file="$1"
    local dir_path
    dir_path="$(dirname "${target_file}")"

    mkdir -p "${dir_path}"
    touch "${target_file}"

    # Remove existing block if present
    if grep -q "${ALIAS_START_MARKER}" "${target_file}" 2>/dev/null; then
      sed -i.bak "/${ALIAS_START_MARKER}/,/${ALIAS_END_MARKER}/d" "${target_file}"
      rm -f "${target_file}.bak"
    fi

    # Append new block
    echo "" >> "${target_file}"
    echo "${COMMON_ALIAS_BLOCK}" >> "${target_file}"

    # Ensure correct ownership
    if [[ $EUID -eq 0 && "${TARGET_USER}" != "root" ]]; then
      chown "${TARGET_USER}" "${target_file}" 2>/dev/null || true
    fi

    ok "Applied alias to ${target_file}"
  }

  # 1. Update ~/.bash_aliases
  BASH_ALIASES_FILE="${USER_HOME}/.bash_aliases"
  apply_aliases_to_file "${BASH_ALIASES_FILE}"

  # 2. Ensure ~/.bashrc sources ~/.bash_aliases
  BASHRC_FILE="${USER_HOME}/.bashrc"
  if [[ -f "${BASHRC_FILE}" ]]; then
    if ! grep -q "\.bash_aliases" "${BASHRC_FILE}"; then
      cat <<'EOF' >> "${BASHRC_FILE}"

# Load bash aliases if available
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
EOF
      if [[ $EUID -eq 0 && "${TARGET_USER}" != "root" ]]; then
        chown "${TARGET_USER}" "${BASHRC_FILE}" 2>/dev/null || true
      fi
      ok "Ensured ~/.bashrc sources ~/.bash_aliases"
    fi
  fi

  # 3. Update ~/.zshrc if exists or if on macOS
  ZSHRC_FILE="${USER_HOME}/.zshrc"
  if [[ -f "${ZSHRC_FILE}" || "$(uname -s)" == "Darwin" ]]; then
    apply_aliases_to_file "${ZSHRC_FILE}"
  fi
fi

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo -e "${GREEN}${BOLD}==========================================================${NC}"
echo -e "${GREEN}${BOLD} Configuration completed successfully!${NC}"
echo -e "${GREEN}${BOLD}==========================================================${NC}"
echo ""
echo "Configured:"
echo -e "  ${CYAN}Git user${NC}         -> ${TARGET_NAME:-$(git config --global user.name)} <${TARGET_EMAIL:-$(git config --global user.email)}>"
echo -e "  ${CYAN}git acp \"<msg>\"${NC} -> git add -A && git commit -m \"<msg>\" && git push"
echo -e "  ${CYAN}alias k='kubectl'${NC}"
echo ""
echo "To use 'k' immediately in your current terminal session, run:"
echo -e "  ${BOLD}source ~/.bashrc${NC}  (or ${BOLD}source ~/.bash_aliases${NC})"
echo ""
