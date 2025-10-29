# 🐳 Docker Container Restart Monitor

A lightweight shell-based monitor that checks if any Docker container has **restarted** and sends a JSON payload to a **webhook URL** (e.g., Slack, Discord, custom API, etc.).

Perfect for small servers or self-hosted environments where you just want a **simple, zero-dependency** heartbeat for container restarts.

---

## ✨ Features

- 🔍 Detects container **restarts** via `RestartCount` comparison
- ⚡ Runs automatically every few minutes using a **systemd timer**
- 🪶 Lightweight — CPU and memory usage near zero
- 🧰 Works with any webhook endpoint
- 🔒 Safe, no Docker socket modification required
- 🧩 Easy to install, update, or remove

---

## 📋 Requirements

- Docker installed and running
- `jq` (JSON processor) - **Required**
- `curl` (usually pre-installed)

Install dependencies:
```bash
# Debian/Ubuntu
sudo apt-get install -y jq curl

# RHEL/CentOS/Fedora
sudo dnf install -y jq curl
```

---

## 🚀 One-Command Installation

Replace `YOUR_WEBHOOK_URL` and optionally set `WEBHOOK_TYPE` (generic, lark, slack, or discord):

```bash
# Generic webhook (default)
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/docker/install.sh)'

# Lark/Feishu webhook
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" WEBHOOK_TYPE="lark" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/docker/install.sh)'

# Slack webhook
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" WEBHOOK_TYPE="slack" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/docker/install.sh)'

# Discord webhook
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" WEBHOOK_TYPE="discord" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/docker/install.sh)'
```

---

## 🧩 How It Works

1. Every 3 minutes (default), the timer triggers the script.
2. The script retrieves each container's `RestartCount`.
3. If a container's restart count increased since the last check, it sends a JSON payload like:
   ```json
   {
     "type": "container_reboot",
     "time": "2025-10-28T10:05:23Z",
     "restartCount": 2,
     "host": "my-server",
     "container": {
       "id": "2a8b6b4f27c8",
       "name": "api-server",
       "image": "nginx:1.27"
     }
   }
   ```

   For Lark/Feishu, the message format is:
   ```
   Container restarted
   Host: my-server
   Name: /api-server
   Image: nginx:1.27
   Restart count: 2
   Time: 2025-10-28T10:05:23Z
   ```

4. The payload is POSTed to your configured webhook endpoint.

**Note:** Built-in support for Lark/Feishu, Slack, Discord, and generic webhooks. Just set `WEBHOOK_TYPE` during installation.

---

## 🧪 Testing

### Test webhook connection
Send a test message to verify your webhook is working:

```bash
# Lark/Feishu
curl -X POST "YOUR_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"msg_type":"text","content":{"text":"Test message from Docker Reboot Monitor"}}'

# Slack
curl -X POST "YOUR_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"text":"Test message from Docker Reboot Monitor"}'

# Discord
curl -X POST "YOUR_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content":"Test message from Docker Reboot Monitor"}'
```

### Test by simulating a container crash

**Important:** Docker's `RestartCount` only increments when the application **inside** the container crashes naturally. Manual `docker stop`, `docker kill`, or `docker restart` commands do NOT increment the count, even if Docker auto-restarts the container.

**To properly test:**

```bash
# Method 1: Kill the container's main process from the host
# Find the process ID
docker inspect CONTAINER_NAME --format '{{.State.Pid}}'

# Kill it directly (simulates real crash)
sudo kill -9 <PID>

# Check if restart count increased
docker inspect CONTAINER_NAME --format "{{.RestartCount}}"

# Method 2: Make the application crash from inside (if you can access it)
# For example, for a web app, trigger a fatal error through the application

# Run the script manually
sudo /usr/local/bin/docker-reboot-monitor.sh

# Check logs for webhook activity
journalctl -u docker-reboot-monitor.service -n 10 --no-pager
```

**Reality check:** If your containers are stable and healthy (RestartCount = 0), there's nothing to test! The monitoring will alert you when a **real crash** happens. You don't need to artificially create crashes to verify it works.

**Note:** Your container must have a restart policy (like `always`, `unless-stopped`, or `on-failure`) for this to work:

```bash
# Check restart policy
docker inspect CONTAINER_NAME --format "{{.HostConfig.RestartPolicy.Name}}"

# If empty or "no", update it:
docker update --restart=unless-stopped CONTAINER_NAME
```

### Manual script test with debugging
Run the script with verbose output:

```bash
# Run manually
sudo /usr/local/bin/docker-reboot-monitor.sh

# Check what happened
echo "Exit code: $?"

# Check state file
cat /var/tmp/docker-restartcount.state
```

---

## 🔍 Troubleshooting

If the service fails to start, check the detailed error log:
```bash
journalctl -u docker-reboot-monitor.service -n 20 --no-pager
```

### Check dependencies
The script requires `docker`, `jq`, and `curl`:
```bash
which docker jq curl
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
sudo /usr/local/bin/docker-reboot-monitor.sh
```

### Common issues
- **Missing jq**: Most common cause. Install with `sudo apt-get install -y jq` or `sudo dnf install -y jq`
- **Docker not running**: Ensure Docker service is running: `sudo systemctl status docker`
- **Permissions**: The script needs to access Docker socket (usually requires root)
- **No running containers**: The script will run successfully but do nothing until containers are started
- **"Unit docker.service not found"**: If Docker is installed via snap, the service is named differently. Fix by re-running the installation, or manually edit `/etc/systemd/system/docker-reboot-monitor.service` and change `docker.service` to `snap.docker.dockerd.service`, then run:
  ```bash
  sudo systemctl daemon-reload
  sudo systemctl restart docker-reboot-monitor.timer
  ```

---

## 🔧 Managing the Timer

### Check status
```bash
systemctl status docker-reboot-monitor.timer
```

### Check last run and next run time
```bash
systemctl list-timers docker-reboot-monitor.timer
```

### View last run log
```bash
journalctl -u docker-reboot-monitor.service -n 1 --no-pager
```

### View recent logs
```bash
journalctl -u docker-reboot-monitor.service -n 50 --no-pager
```

### Pause or disable
```bash
sudo systemctl stop docker-reboot-monitor.timer      # stop temporarily
sudo systemctl disable --now docker-reboot-monitor.timer  # disable permanently
```

### Restart or reload
```bash
sudo systemctl daemon-reload
sudo systemctl restart docker-reboot-monitor.timer
```

---

## ⚙️ Configuration

### Change any setting
Just re-run the install script with new values:

```bash
# Change interval (default: 3min)
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" INTERVAL="5min" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/docker/install.sh)'

# Change webhook URL
sudo bash -c 'WEBHOOK_URL="https://new.webhook/endpoint" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/docker/install.sh)'

# Change webhook type
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" WEBHOOK_TYPE="slack" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/docker/install.sh)'

# Change multiple settings at once
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" WEBHOOK_TYPE="lark" INTERVAL="10min" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/docker/install.sh)'
```

The script will update the configuration and restart the timer automatically.

---

## 🛠 Uninstall
```bash
sudo bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/docker/uninstall.sh)
```

---

## 🔧 Webhook Customization

Need to change webhook type? Just re-run the install command with a different `WEBHOOK_TYPE`:

```bash
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" WEBHOOK_TYPE="lark" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/docker/install.sh)'
```

Supported types: `generic`, `lark`, `slack`, `discord`

---

## 🧠 Tips
- **Multi-host setups**: Hostname is automatically included in all alerts, so you can easily identify which server had a restart.
- **Filter monitored containers**: Edit `/usr/local/bin/docker-reboot-monitor.sh` and change `docker ps -q` to `docker ps -q --filter label=monitor=true` to only monitor tagged containers.
- **Adjust interval**: Use `INTERVAL="10min"` during installation for large hosts or less frequent checks.

---

## 📜 License
MIT License © 2025
Created by [guo](https://github.com/guo)

---

### ⭐️ Why This Exists
Most observability stacks are heavy and overkill for small setups.
This tiny script fills the gap: **just tell me if my container restarted.**
