# 📊 Process Restart Monitor

A lightweight shell-based monitor that detects when system processes die or services restart, then sends webhook notifications (Slack, Discord, Lark, custom API, etc.).

Perfect for monitoring critical processes on servers without Docker or when you need to track systemd service health.

---

## ✨ Features

- 🔄 Detects **systemd service restarts** via `NRestarts` property
- 💀 Detects when **regular processes die/get killed**
- ⚡ Runs automatically every few minutes using a **systemd timer**
- 🪶 Lightweight — CPU and memory usage near zero
- 🧰 Works with any webhook endpoint
- 🔒 Safe and non-intrusive
- 🧩 Easy to install, update, or remove

---

## 📋 Requirements

- Linux operating system (uses `/proc` filesystem)
- `jq` (JSON processor) - **Required**
- `curl` (usually pre-installed)
- `systemd` (recommended for service monitoring)

Install dependencies:
```bash
# Debian/Ubuntu
sudo apt-get install -y jq curl

# RHEL/CentOS/Fedora
sudo dnf install -y jq curl
```

---

## 🚀 One-Command Installation

**Required**: You must specify `MONITOR_PROCESSES` with comma-separated process names:

```bash
# Generic webhook (default)
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" MONITOR_PROCESSES="nginx,postgresql,myapp" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'

# Lark/Feishu webhook
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" WEBHOOK_TYPE="lark" MONITOR_PROCESSES="nginx,redis" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'

# Slack webhook
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" WEBHOOK_TYPE="slack" MONITOR_PROCESSES="postgresql,myapp" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'

# Discord webhook
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" WEBHOOK_TYPE="discord" MONITOR_PROCESSES="nginx" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'

# Monitor specific PIDs
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" MONITOR_PROCESSES="pid:12345,pid:67890" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'

# Mix service names, process names, and PIDs
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" MONITOR_PROCESSES="nginx,myapp,pid:12345" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'
```

---

## 🧩 How It Works

The script monitors processes in three different ways:

### 1. Systemd Services (Recommended)

For systemd-managed services (nginx, postgresql, redis, etc.):
- Checks restart count: `systemctl show SERVICE --property=NRestarts`
- When restart count increases → sends webhook alert
- **Most reliable** because systemd tracks this automatically

Example: If nginx service restarts, systemd increments `NRestarts` and the monitor detects it.

### 2. Regular Processes (By Name)

For processes not managed by systemd:
- Uses `pgrep` to check if process exists by name
- Tracks state: "running" or "stopped"
- When process was "running" but now gone → sends webhook alert
- Counts how many times the process has died

Example: If you run `pkill myapp`, the next check detects the process is gone and sends an alert.

### 3. Specific Process IDs

For monitoring specific process instances:
- Use format: `pid:12345`
- Checks if `/proc/PID` exists (Linux-specific)
- Tracks when that specific PID disappears
- Useful when multiple processes have the same name
- Retrieves process name from `/proc/PID/comm` for alert context

Example: `MONITOR_PROCESSES="pid:12345,pid:67890"` monitors those specific PIDs

**Note**: PID monitoring requires Linux with `/proc` filesystem.

### Payload Example

```json
{
  "type": "process_event",
  "time": "2025-10-29T10:05:23Z",
  "restartCount": 3,
  "host": "my-server",
  "process": {
    "id": "nginx",
    "name": "nginx (service)",
    "type": "systemd service restarted"
  }
}
```

For Lark/Feishu:
```
Process event
Host: my-server
Name: nginx (service)
Type: systemd service restarted
Count: 3
Time: 2025-10-29T10:05:23Z
```

---

## 🧪 Testing

### Test webhook connection

```bash
# Lark/Feishu
curl -X POST "YOUR_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"msg_type":"text","content":{"text":"Test message from Process Restart Monitor"}}'

# Slack
curl -X POST "YOUR_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"text":"Test message from Process Restart Monitor"}'

# Discord
curl -X POST "YOUR_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content":"Test message from Process Restart Monitor"}'
```

### Test systemd service monitoring

```bash
# Restart a monitored systemd service
sudo systemctl restart nginx

# Check restart count increased
systemctl show nginx --property=NRestarts

# Wait for next check (or run manually)
sudo /usr/local/bin/process-restart-monitor.sh

# Check logs for webhook activity
journalctl -u process-restart-monitor.service -n 10 --no-pager
```

### Test regular process monitoring

```bash
# Kill a monitored process
pkill myapp

# Run the monitor script manually (will detect the process is gone)
sudo /usr/local/bin/process-restart-monitor.sh

# Check logs
journalctl -u process-restart-monitor.service -n 10 --no-pager

# Note: If you restart the process after killing it, no alert is sent
# Only the death/termination is detected
```

### Test PID monitoring

```bash
# Find the PID of a running process
pgrep myapp
# Output: 12345

# Install monitor with that PID
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" MONITOR_PROCESSES="pid:12345" bash install.sh'

# Kill that specific process
kill 12345

# Run the monitor script manually (will detect the PID is gone)
sudo /usr/local/bin/process-restart-monitor.sh

# Check logs - you'll see alert for PID 12345
journalctl -u process-restart-monitor.service -n 10 --no-pager
```

### Manual script test with debugging

```bash
# Run manually
sudo /usr/local/bin/process-restart-monitor.sh

# Check what happened
echo "Exit code: $?"

# Check state file
cat /var/tmp/process-restartcount.state
```

---

## 🔍 Troubleshooting

If the service fails to start, check the detailed error log:
```bash
journalctl -u process-restart-monitor.service -n 20 --no-pager
```

### Check dependencies

```bash
which jq curl
```

If any are missing, install them:
```bash
# Debian/Ubuntu
sudo apt-get install -y jq curl

# RHEL/CentOS/Fedora
sudo dnf install -y jq curl
```

### Test the script manually
Run the monitoring script directly to see any errors:
```bash
sudo /usr/local/bin/process-restart-monitor.sh
```

### Common issues

- **Missing jq**: Most common cause. Install with `sudo apt-get install -y jq` or `sudo dnf install -y jq`
- **Process name mismatch**: Make sure the process name matches what `pgrep` would find. Test with `pgrep YOUR_PROCESS_NAME`
- **Service not found**: For systemd services, verify service exists: `systemctl list-units | grep YOUR_SERVICE`
- **No alerts triggered**:
  - For systemd services: Only detects when restart count increases
  - For regular processes: Only detects when running process disappears
- **Permissions**: Some commands may require root privileges

---

## 🔧 Managing the Timer

### Check status
```bash
systemctl status process-restart-monitor.timer
```

### Check last run and next run time
```bash
systemctl list-timers process-restart-monitor.timer
```

### View last run log
```bash
journalctl -u process-restart-monitor.service -n 1 --no-pager
```

### View recent logs
```bash
journalctl -u process-restart-monitor.service -n 50 --no-pager
```

### Pause or disable
```bash
sudo systemctl stop process-restart-monitor.timer      # stop temporarily
sudo systemctl disable --now process-restart-monitor.timer  # disable permanently
```

### Restart or reload
```bash
sudo systemctl daemon-reload
sudo systemctl restart process-restart-monitor.timer
```

---

## ⚙️ Configuration

### Change any setting
Just re-run the install script with new values:

```bash
# Change interval (default: 3min)
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" MONITOR_PROCESSES="nginx" INTERVAL="5min" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'

# Change webhook URL
sudo bash -c 'WEBHOOK_URL="https://new.webhook/endpoint" MONITOR_PROCESSES="nginx,redis" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'

# Change webhook type
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" WEBHOOK_TYPE="slack" MONITOR_PROCESSES="postgresql" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'

# Add or change monitored processes
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" MONITOR_PROCESSES="nginx,redis,postgresql,myapp" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'

# Change multiple settings at once
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" WEBHOOK_TYPE="lark" INTERVAL="10min" MONITOR_PROCESSES="nginx" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'
```

The script will update the configuration and restart the timer automatically.

---

## 🛠 Uninstall
```bash
sudo bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/uninstall.sh)
```

---

## 🔧 Webhook Customization

Supported types: `generic`, `lark`, `slack`, `discord`

Change webhook type by re-running the install command:

```bash
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" WEBHOOK_TYPE="lark" MONITOR_PROCESSES="nginx" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'
```

---

## 🧠 Tips

- **Choosing the right monitoring method**:
  - **Systemd services**: Best option - reliable restart tracking
  - **Process by name**: Use for non-systemd processes - detects when process dies
  - **Process by PID**: Use when you need to track a specific process instance
- **Process names**: Make sure the name matches what `pgrep` finds. Test first: `pgrep YOUR_PROCESS`
- **PID format**: Always use `pid:12345` format (with `pid:` prefix)
- **Multiple instances**: If you have multiple processes with the same name, use PIDs to track specific instances
- **Multi-host setups**: Hostname is automatically included in all alerts
- **Adjust interval**: Use `INTERVAL="10min"` for less frequent checks
- **State file**: Located at `/var/tmp/process-restartcount.state`
  - Stores current state (running/stopped) for each process
  - Stores death count for regular processes and PIDs
  - Stores last restart count for systemd services
  - Stores process name for monitored PIDs (for alert context)

---

## 📊 Understanding the Monitoring Behavior

### Systemd Services
- ✅ Detects: Service restarts (automatic or manual)
- ✅ Counts: Total restart count from systemd
- ❌ Does not detect: Service stop without restart

### Regular Processes (By Name)
- ✅ Detects: Process termination (killed, crashed, stopped)
- ✅ Counts: How many times process died since monitoring started
- ❌ Does not detect: Process restarts (only death events)
- ⚠️ Limitation: Monitors first matching process if multiple instances exist

### Specific PIDs
- ✅ Detects: When that specific PID terminates
- ✅ Counts: How many times that PID died (useful if process restarts with same PID)
- ✅ Precision: Tracks exact process instance, not just name
- ⚠️ Limitation: If process restarts with new PID, you need to update configuration

### Best Practices
- Use systemd services whenever possible for most reliable tracking
- Use PIDs when you need to track specific process instances
- Use process names for simple monitoring of non-systemd processes
- Test process names with `pgrep` before adding to `MONITOR_PROCESSES`
- Get PIDs with `pgrep PROCESS_NAME` or `pidof PROCESS_NAME`

---

## 📜 License
MIT License © 2025
Created by [guo](https://github.com/guo)

---

### ⭐️ Why This Exists
Most observability stacks are heavy and overkill for small setups.
This tiny script fills the gap: **just tell me when my critical process fails.**
