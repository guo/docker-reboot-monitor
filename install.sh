#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${WEBHOOK_URL:-}" ]]; then
  echo "Error: WEBHOOK_URL environment variable is required"
  echo "Usage: WEBHOOK_URL=\"https://your.webhook/endpoint\" [INTERVAL=3min] bash install.sh"
  exit 1
fi

# Set default interval if not provided
INTERVAL="${INTERVAL:-3min}"

# Create the monitoring script
cat >/usr/local/bin/docker-reboot-monitor.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
STATE_FILE="/var/tmp/docker-restartcount.state"
declare -A last
[[ -f "$STATE_FILE" ]] && source "$STATE_FILE" || true
while read -r rc name image id; do
  key="c_${id}"; prev="${last[$key]:-0}"
  if [[ "$rc" -gt "${prev:-0}" ]]; then
    payload=$(jq -n --arg id "$id" --arg name "$name" --arg image "$image" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson restartCount "$rc" "{type:\"container_reboot\",time:\$ts,restartCount:\$restartCount,container:{id:\$id,name:\$name,image:\$image}}")
    curl -sS -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" --data "$payload" || true
  fi
  last[$key]="$rc"
done < <(docker inspect $(docker ps -q) --format "{{.RestartCount}} {{.Name}} {{.Config.Image}} {{.ID}}")
{ echo "# autogen"; for k in "${!last[@]}"; do echo "last[$k]=${last[$k]}"; done; } > "$STATE_FILE"
EOF

# Replace WEBHOOK_URL placeholder with actual value
sed -i.bak "s|\$WEBHOOK_URL|$WEBHOOK_URL|g" /usr/local/bin/docker-reboot-monitor.sh
rm -f /usr/local/bin/docker-reboot-monitor.sh.bak
chmod +x /usr/local/bin/docker-reboot-monitor.sh

# Create systemd service
cat >/etc/systemd/system/docker-reboot-monitor.service <<EOF
[Unit]
Description=Check docker container reboot and send webhook
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/docker-reboot-monitor.sh
EOF

# Create systemd timer
cat >/etc/systemd/system/docker-reboot-monitor.timer <<EOF
[Unit]
Description=Run docker reboot monitor every $INTERVAL

[Timer]
OnBootSec=1min
OnUnitActiveSec=$INTERVAL
Unit=docker-reboot-monitor.service

[Install]
WantedBy=timers.target
EOF

# Enable and start the timer
systemctl daemon-reload
systemctl enable --now docker-reboot-monitor.timer

echo "✅ Installed! Checking every $INTERVAL → $WEBHOOK_URL"
