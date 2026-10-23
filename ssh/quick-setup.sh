#!/usr/bin/env bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpMcx7qyhtxaZ4EuAlS2EQwa145fO8/g5fvIES4vsty shubh@Shubhams-MacBook-Air.local" >> ~/.ssh/authorized_keys && \
chmod 600 ~/.ssh/authorized_keys && \
(sudo systemctl enable --now ssh 2>/dev/null || sudo systemctl enable --now sshd 2>/dev/null || sudo service ssh start 2>/dev/null || true) && \
echo "Ready to connect: ssh $(whoami)@$(hostname -I 2>/dev/null | awk '{print $1}')"
