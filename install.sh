#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${WEBHOOK_URL:-}" ]]; then
  echo "Error: WEBHOOK_URL environment variable is required"
  echo "Usage: WEBHOOK_URL=\"https://your.webhook/endpoint\" [WEBHOOK_TYPE=generic|lark|slack|discord] [INTERVAL=3min] bash install.sh"
  exit 1
fi

# Set defaults
INTERVAL="${INTERVAL:-3min}"
WEBHOOK_TYPE="${WEBHOOK_TYPE:-generic}"

# Generate payload command based on webhook type
case "$WEBHOOK_TYPE" in
  lark|feishu)
    PAYLOAD_CMD='payload=$(jq -n --arg id "$id" --arg name "$name" --arg image "$image" --arg host "$(hostname)" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson restartCount "$rc" '\''{msg_type:"text",content:{text:"Container restarted\nHost: \($host)\nName: \($name)\nImage: \($image)\nRestart count: \($restartCount)\nTime: \($ts)"}}'\'')'
    ;;
  slack)
    PAYLOAD_CMD='payload=$(jq -n --arg id "$id" --arg name "$name" --arg image "$image" --arg host "$(hostname)" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson restartCount "$rc" '\''{text:":warning: Container *\($name)* restarted (\($restartCount)x) on `\($host)`\nImage: `\($image)`\nTime: \($ts)"}'\'')'
    ;;
  discord)
    PAYLOAD_CMD='payload=$(jq -n --arg id "$id" --arg name "$name" --arg image "$image" --arg host "$(hostname)" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson restartCount "$rc" '\''{content:":warning: Container **\($name)** restarted (\($restartCount)x) on `\($host)`\nImage: `\($image)`\nTime: \($ts)"}'\'')'
    ;;
  *)
    PAYLOAD_CMD='payload=$(jq -n --arg id "$id" --arg name "$name" --arg image "$image" --arg host "$(hostname)" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson restartCount "$rc" '\''{type:"container_reboot",time:$ts,restartCount:$restartCount,host:$host,container:{id:$id,name:$name,image:$image}}'\'')'
    ;;
esac

# Create the monitoring script
cat >/usr/local/bin/docker-reboot-monitor.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
STATE_FILE="/var/tmp/docker-restartcount.state"
declare -A last
[[ -f "\$STATE_FILE" ]] && source "\$STATE_FILE" || true

# Get running containers
containers=\$(docker ps -q)
if [[ -z "\$containers" ]]; then
  # No containers running, just update state file and exit
  { echo "# autogen"; for k in "\${!last[@]}"; do echo "last[\$k]=\${last[\$k]}"; done; } > "\$STATE_FILE"
  exit 0
fi

while read -r rc name image id; do
  key="c_\${id}"; prev="\${last[\$key]:-0}"
  if [[ "\$rc" -gt "\${prev:-0}" ]]; then
    $PAYLOAD_CMD
    curl -sS -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" --data "\$payload" || true
  fi
  last[\$key]="\$rc"
done < <(docker inspect \$containers --format "{{.RestartCount}} {{.Name}} {{.Config.Image}} {{.ID}}")
{ echo "# autogen"; for k in "\${!last[@]}"; do echo "last[\$k]=\${last[\$k]}"; done; } > "\$STATE_FILE"
EOF

chmod +x /usr/local/bin/docker-reboot-monitor.sh

# Detect Docker service name
DOCKER_SERVICE="docker.service"
if systemctl list-units --type=service --all | grep -q "snap.docker.dockerd.service"; then
  DOCKER_SERVICE="snap.docker.dockerd.service"
fi

# Create systemd service
cat >/etc/systemd/system/docker-reboot-monitor.service <<EOF
[Unit]
Description=Check docker container reboot and send webhook
After=$DOCKER_SERVICE
Wants=$DOCKER_SERVICE

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

echo "✅ Installed! Type: $WEBHOOK_TYPE | Interval: $INTERVAL | Webhook: $WEBHOOK_URL"
