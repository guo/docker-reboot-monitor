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

# Monitor by command pattern (great for bun/node apps)
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" MONITOR_PROCESSES="cmd:bun.*server,cmd:node.*app.js" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'

# Mix all formats
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" MONITOR_PROCESSES="nginx,pid:12345,cmd:bun.*server" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'
```

---

## 🧩 How It Works

The script monitors processes in four different ways:

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
- Shows full command line from `/proc/PID/cmdline` in alerts

Example: `MONITOR_PROCESSES="pid:12345,pid:67890"` monitors those specific PIDs

**Note**: PID monitoring requires Linux with `/proc` filesystem.

### 4. Command Pattern Matching (Best for bun/node)

For monitoring processes by their command line:
- Use format: `cmd:pattern` (supports regex)
- Uses `pgrep -f` to find processes matching the pattern
- Perfect for distinguishing between multiple `bun` or `node` processes
- Shows full command line in alerts
- Automatically tracks the PID of the matching process

Examples:
- `cmd:bun.*server` - matches "bun run server.ts", "bun server.js", etc.
- `cmd:node.*app.js` - matches "node app.js", "node dist/app.js", etc.
- `cmd:bun run dev` - matches exactly "bun run dev"

**Perfect for** distinguishing between:
```
64560  bun run server.ts --port 3000
89246  bun run worker.ts
89247  bun run queue.ts
```

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

## 🔍 Finding Process PIDs

### Method 1: Using pgrep (recommended)

```bash
# Find all processes by name
pgrep bun
# Output: 64560, 89246, 89247

# Find processes with full command line matching
pgrep -f "bun run server"
# Output: 64560

pgrep -f "node.*app.js"
# Output: 12345
```

### Method 2: Using ps with grep

```bash
# Show all bun processes with full commands
ps aux | grep bun | grep -v grep
# Output:
# user  64560  ... bun run server.ts --port 3000
# user  89246  ... bun run worker.ts
# user  89247  ... bun run queue.ts

# Get specific PID
ps aux | grep "bun run server" | grep -v grep | awk '{print $2}'
# Output: 64560
```

### Method 3: Using pidof

```bash
# Simple process name lookup
pidof nginx
# Output: 1234 5678 9012

# Note: pidof doesn't search command line, only process names
```

### Recommended: Use command patterns instead

Instead of manually finding PIDs, use the `cmd:pattern` format:

```bash
# Instead of:
# 1. Find PID: pgrep -f "bun run server" → 64560
# 2. MONITOR_PROCESSES="pid:64560"

# Just do:
MONITOR_PROCESSES="cmd:bun run server"
# Or with regex:
MONITOR_PROCESSES="cmd:bun.*server"
```

The command pattern automatically finds and tracks the matching process!

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
  - **Command patterns** (`cmd:pattern`): Perfect for bun/node apps with multiple instances
  - **Process by name**: Use for non-systemd processes with unique names
  - **Process by PID**: Use when you need to track a very specific process instance
- **Process names**: Make sure the name matches what `pgrep` finds. Test first: `pgrep YOUR_PROCESS`
- **Command patterns**: Support regex - `cmd:bun.*server` matches any bun command containing "server"
- **PID format**: Always use `pid:12345` format (with `pid:` prefix)
- **Finding PIDs**: Use `pgrep -f "pattern"` or `ps aux | grep "pattern"` (see "Finding Process PIDs" section)
- **Multiple bun/node processes**: Use command patterns instead of PIDs: `cmd:bun run server`, `cmd:node app.js`
- **Multi-host setups**: Hostname is automatically included in all alerts
- **Adjust interval**: Use `INTERVAL="10min"` for less frequent checks
- **State file**: Located at `/var/tmp/process-restartcount.state`
  - Stores current state (running/stopped) for each process
  - Stores death count for regular processes and PIDs
  - Stores last restart count for systemd services
  - Stores full command line for better alerts

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
- ✅ Shows: Full command line in alerts
- ⚠️ Limitation: If process restarts with new PID, you need to update configuration

### Command Patterns
- ✅ Detects: When matching process terminates
- ✅ Counts: How many times the process died
- ✅ Flexible: Uses regex patterns to match command lines
- ✅ Shows: Full command line in alerts
- ✅ Auto-tracks: Automatically finds new PID if process restarts
- ⚠️ Limitation: Monitors first matching process if multiple matches exist

### Best Practices
- Use systemd services whenever possible for most reliable tracking
- **Use command patterns for bun/node apps** - better than PIDs since it survives restarts
- Use PIDs only when you need to track a very specific process instance
- Use process names for simple monitoring of non-systemd processes
- Test patterns with `pgrep -f "pattern"` before adding to `MONITOR_PROCESSES`
- Get PIDs with `pgrep -f "pattern"` or `ps aux | grep "pattern"`

---

## 📜 License
MIT License © 2025
Created by [guo](https://github.com/guo)

---

### ⭐️ Why This Exists
Most observability stacks are heavy and overkill for small setups.
This tiny script fills the gap: **just tell me when my critical process fails.**
