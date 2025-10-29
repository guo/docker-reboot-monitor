#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${WEBHOOK_URL:-}" ]]; then
  echo "Error: WEBHOOK_URL environment variable is required"
  echo "Usage: WEBHOOK_URL=\"https://your.webhook/endpoint\" [WEBHOOK_TYPE=generic|lark|slack|discord] [INTERVAL=3min] MONITOR_PROCESSES=\"process1,process2,pid:12345\" bash install.sh"
  exit 1
fi

if [[ -z "${MONITOR_PROCESSES:-}" ]]; then
  echo "Error: MONITOR_PROCESSES environment variable is required"
  echo "Examples:"
  echo "  MONITOR_PROCESSES=\"nginx,postgresql,myapp\"          # Monitor by name"
  echo "  MONITOR_PROCESSES=\"nginx,pid:12345\"                 # Mix names and PIDs"
  echo "  MONITOR_PROCESSES=\"pid:12345,pid:67890\"             # Monitor specific PIDs"
  exit 1
fi

# Set defaults
INTERVAL="${INTERVAL:-3min}"
WEBHOOK_TYPE="${WEBHOOK_TYPE:-generic}"

# Generate payload command based on webhook type
case "$WEBHOOK_TYPE" in
  lark|feishu)
    PAYLOAD_CMD='payload=$(jq -n --arg id "$id" --arg name "$name" --arg image "$image" --arg host "$(hostname)" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson restartCount "$rc" '\''{msg_type:"text",content:{text:"Process event\nHost: \($host)\nName: \($name)\nType: \($image)\nCount: \($restartCount)\nTime: \($ts)"}}'\'')'
    ;;
  slack)
    PAYLOAD_CMD='payload=$(jq -n --arg id "$id" --arg name "$name" --arg image "$image" --arg host "$(hostname)" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson restartCount "$rc" '\''{text:":warning: Process *\($name)* event (\($restartCount)x) on `\($host)`\nType: `\($image)`\nTime: \($ts)"}'\'')'
    ;;
  discord)
    PAYLOAD_CMD='payload=$(jq -n --arg id "$id" --arg name "$name" --arg image "$image" --arg host "$(hostname)" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson restartCount "$rc" '\''{content:":warning: Process **\($name)** event (\($restartCount)x) on `\($host)`\nType: `\($image)`\nTime: \($ts)"}'\'')'
    ;;
  *)
    PAYLOAD_CMD='payload=$(jq -n --arg id "$id" --arg name "$name" --arg image "$image" --arg host "$(hostname)" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson restartCount "$rc" '\''{type:"process_event",time:$ts,restartCount:$restartCount,host:$host,process:{id:$id,name:$name,type:$image}}'\'')'
    ;;
esac

# Create the monitoring script
cat >/usr/local/bin/process-restart-monitor.sh <<'SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail
STATE_FILE="/var/tmp/process-restartcount.state"
declare -A last
[[ -f "$STATE_FILE" ]] && source "$STATE_FILE" || true

WEBHOOK_URL="WEBHOOK_URL_PLACEHOLDER"
MONITOR_PROCESSES="MONITOR_PROCESSES_PLACEHOLDER"

send_webhook() {
  local id="$1" name="$2" image="$3" rc="$4" type="${5:-process}"
  PAYLOAD_CMD_PLACEHOLDER
  curl -sS -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" --data "$payload" || true
}

# Monitor processes
if [[ -n "$MONITOR_PROCESSES" ]]; then
  IFS=',' read -ra PROCESSES <<< "$MONITOR_PROCESSES"
  for proc in "${PROCESSES[@]}"; do
    proc=$(echo "$proc" | xargs)  # trim whitespace
    [[ -z "$proc" ]] && continue

    # Check if it's a PID (format: pid:12345)
    if [[ "$proc" =~ ^pid:([0-9]+)$ ]]; then
      # Monitor specific PID
      target_pid="${BASH_REMATCH[1]}"
      key="pid_${target_pid}"
      was_running="${last[$key]:-}"

      if [[ -d "/proc/$target_pid" ]]; then
        # PID exists
        if [[ "$was_running" != "running" ]]; then
          # First time seeing this PID running, get process name
          proc_name=$(cat "/proc/$target_pid/comm" 2>/dev/null || echo "unknown")
        fi
        last[$key]="running"
      else
        # PID no longer exists
        if [[ "$was_running" == "running" ]]; then
          # Process was running before, now it's gone
          death_key="d_pid_${target_pid}"
          death_count=${last[$death_key]:-0}
          death_count=$((death_count + 1))
          last[$death_key]=$death_count

          proc_name=$(echo "${last[name_${target_pid}]:-unknown}")
          send_webhook "pid:$target_pid" "PID $target_pid ($proc_name)" "process died/killed" "$death_count" "process"
        fi
        last[$key]="stopped"
      fi
      # Store process name for later reference
      if [[ -d "/proc/$target_pid" ]]; then
        proc_name=$(cat "/proc/$target_pid/comm" 2>/dev/null || echo "unknown")
        last["name_${target_pid}"]="$proc_name"
      fi
    # Try systemd service
    elif systemctl is-active --quiet "$proc" 2>/dev/null || systemctl list-units --all | grep -q "^\s*$proc.service"; then
      # Systemd service
      restarts=$(systemctl show "$proc" --property=NRestarts --value 2>/dev/null || echo "0")
      key="s_${proc}"
      prev="${last[$key]:-0}"

      if [[ "$restarts" -gt "$prev" ]]; then
        send_webhook "$proc" "$proc (service)" "systemd service restarted" "$restarts" "process"
      fi
      last[$key]="$restarts"
    else
      # Regular process by name - detect if it's gone/killed
      pid=$(pgrep "$proc" 2>/dev/null | head -n 1)
      key="p_${proc}"
      was_running="${last[$key]:-}"

      if [[ -z "$pid" ]]; then
        # Process is not running
        if [[ "$was_running" == "running" ]]; then
          # Process was running before, now it's gone
          death_key="d_${proc}"
          death_count=${last[$death_key]:-0}
          death_count=$((death_count + 1))
          last[$death_key]=$death_count

          send_webhook "$proc" "$proc (process)" "process died/killed" "$death_count" "process"
        fi
        last[$key]="stopped"
      else
        # Process is running
        last[$key]="running"
      fi
    fi
  done
fi

{ echo "# autogen"; for k in "${!last[@]}"; do echo "last[$k]=${last[$k]}"; done; } > "$STATE_FILE"
SCRIPT_EOF

# Replace placeholders
sed -i.bak "s|WEBHOOK_URL_PLACEHOLDER|${WEBHOOK_URL}|g" /usr/local/bin/process-restart-monitor.sh
sed -i.bak "s|MONITOR_PROCESSES_PLACEHOLDER|${MONITOR_PROCESSES}|g" /usr/local/bin/process-restart-monitor.sh
sed -i.bak "s|PAYLOAD_CMD_PLACEHOLDER|${PAYLOAD_CMD}|g" /usr/local/bin/process-restart-monitor.sh
rm -f /usr/local/bin/process-restart-monitor.sh.bak

chmod +x /usr/local/bin/process-restart-monitor.sh

# Create systemd service (no Docker dependency)
cat >/etc/systemd/system/process-restart-monitor.service <<EOF
[Unit]
Description=Check process restarts and send webhook

[Service]
Type=oneshot
ExecStart=/usr/local/bin/process-restart-monitor.sh
EOF

# Create systemd timer
cat >/etc/systemd/system/process-restart-monitor.timer <<EOF
[Unit]
Description=Run process restart monitor every $INTERVAL

[Timer]
OnBootSec=1min
OnUnitActiveSec=$INTERVAL
Unit=process-restart-monitor.service

[Install]
WantedBy=timers.target
EOF

# Enable and start the timer
systemctl daemon-reload
systemctl enable --now process-restart-monitor.timer

echo "✅ Installed! Type: $WEBHOOK_TYPE | Interval: $INTERVAL | Webhook: $WEBHOOK_URL"
echo "📊 Monitoring processes: $MONITOR_PROCESSES"
