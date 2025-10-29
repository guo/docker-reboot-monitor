#!/usr/bin/env bash
set -euo pipefail

echo "Uninstalling Docker Reboot Monitor..."

# Stop and disable the timer
systemctl disable --now docker-reboot-monitor.timer 2>/dev/null || true

# Remove files
rm -f /usr/local/bin/docker-reboot-monitor.sh \
      /etc/systemd/system/docker-reboot-monitor.service \
      /etc/systemd/system/docker-reboot-monitor.timer \
      /var/tmp/docker-restartcount.state

# Reload systemd
systemctl daemon-reload

echo "✅ Docker Reboot Monitor removed."
