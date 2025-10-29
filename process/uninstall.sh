#!/usr/bin/env bash
set -euo pipefail

echo "🧹 Uninstalling process restart monitor..."

# Stop and disable timer
systemctl stop process-restart-monitor.timer 2>/dev/null || true
systemctl disable process-restart-monitor.timer 2>/dev/null || true

# Remove systemd files
rm -f /etc/systemd/system/process-restart-monitor.service
rm -f /etc/systemd/system/process-restart-monitor.timer

# Remove script
rm -f /usr/local/bin/process-restart-monitor.sh

# Remove state file
rm -f /var/tmp/process-restartcount.state

# Reload systemd
systemctl daemon-reload

echo "✅ Process restart monitor uninstalled successfully!"
