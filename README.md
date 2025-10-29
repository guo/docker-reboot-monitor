# 🐳 Docker Reboot Monitor

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

## 🚀 One-Command Installation

Replace `YOUR_WEBHOOK_URL` and run as root:

```bash
WEBHOOK_URL="YOUR_WEBHOOK_URL" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/install.sh)
```

---

## 🧩 How It Works
1. Every 3 minutes, the timer triggers the script.  
2. The script retrieves each container’s `RestartCount`.  
3. If a container’s restart count increased since the last check, it sends a JSON payload like:
   ```json
   {
     "type": "container_reboot",
     "time": "2025-10-28T10:05:23Z",
     "restartCount": 2,
     "container": {
       "id": "2a8b6b4f27c8",
       "name": "api-server",
       "image": "nginx:1.27"
     }
   }
   ```
4. The payload is POSTed to your configured webhook endpoint.

---

## 🔧 Managing the Timer

### Check status
```bash
systemctl status docker-reboot-monitor.timer
systemctl list-timers | grep docker-reboot-monitor
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

### Change interval
Just re-run the install script with a different interval (default is `3min`):
```bash
WEBHOOK_URL="YOUR_WEBHOOK_URL" INTERVAL="5min" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/install.sh)
```

### Change webhook URL
Just re-run the install script with the new webhook URL:
```bash
WEBHOOK_URL="https://new.webhook/endpoint" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/install.sh)
```

The script will update the configuration and restart the timer automatically.

---

## 🛠 Uninstall
```bash
bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/uninstall.sh)
```

---

## 🧠 Tips
- Filter monitored containers:  
  Change  
  ```bash
  docker ps -q
  ```  
  to  
  ```bash
  docker ps -q --filter label=monitor=true
  ```  
  inside the script.
- Increase interval (e.g., 5–10 minutes) for large hosts.  
- Add hostname or signature to payload for multi-host setups.

---

## 📜 License
MIT License © 2025
Created by [guo](https://github.com/guo)

---

### ⭐️ Why This Exists
Most observability stacks are heavy and overkill for small setups.  
This tiny script fills the gap: **just tell me if my container restarted.**
