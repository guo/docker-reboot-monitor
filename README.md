# 🔔 Restart Monitor

Lightweight shell-based monitors that detect restarts and send webhook notifications (Slack, Discord, Lark, custom API, etc.).

Perfect for small servers or self-hosted environments where you just want a **simple, zero-dependency** alert system.

---

## 📦 Two Separate Monitors

This repository contains **two independent monitoring tools**:

### 🐳 Docker Container Restart Monitor
- Monitors Docker containers for restarts
- Tracks `RestartCount` changes
- → [Docker Monitor Documentation](docker/)

### 📊 Process Restart Monitor
- Monitors system processes and systemd services
- Detects when processes die or services restart
- → [Process Monitor Documentation](process/)

**You can install both if needed** - they run independently and don't interfere with each other.

---

## ✨ Common Features

Both monitors share:
- ⚡ Automatic checks via **systemd timer**
- 🪶 Lightweight — near-zero CPU and memory usage
- 🧰 Support for multiple webhook types (generic, Lark, Slack, Discord)
- 🔒 Safe and non-intrusive
- 🧩 Easy to install, update, or remove

---

## 🚀 Quick Start

### Docker Container Monitor

```bash
# Install Docker container restart monitor
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/docker/install.sh)'
```

**Requirements**: Docker, jq, curl

### Process Monitor

```bash
# Install process restart monitor
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" MONITOR_PROCESSES="nginx,postgresql,myapp" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'
```

**Requirements**: jq, curl (systemd recommended)

---

## 📋 Webhook Types

Both monitors support the same webhook formats:

- **generic** (default) - JSON payload with structured data
- **lark** / **feishu** - Lark/Feishu format
- **slack** - Slack incoming webhook format
- **discord** - Discord webhook format

Set with `WEBHOOK_TYPE` environment variable during installation.

---

## 📚 Documentation

### Docker Container Monitor
- [Full Documentation](docker/README.md)
- [Installation Guide](docker/)
- [Uninstall](docker/uninstall.sh)

### Process Monitor
- [Full Documentation](process/README.md)
- [Installation Guide](process/)
- [Uninstall](process/uninstall.sh)

---

## 🧠 When to Use Which?

| Use Case | Monitor | Why |
|----------|---------|-----|
| Docker containers restarting | Docker Monitor | Tracks Docker's built-in restart counter |
| Systemd service failures | Process Monitor | Uses systemd's restart tracking |
| Non-systemd process crashes | Process Monitor | Detects when process disappears |
| Both containers and processes | Both monitors | Install both - they work independently |

---

## 🛠 Installing Both Monitors

You can run both monitors simultaneously:

```bash
# Install Docker monitor
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/docker/install.sh)'

# Install Process monitor
sudo bash -c 'WEBHOOK_URL="YOUR_WEBHOOK_URL" MONITOR_PROCESSES="nginx,postgresql" bash <(curl -sSL https://raw.githubusercontent.com/guo/docker-reboot-monitor/main/process/install.sh)'
```

They use separate:
- Systemd services (`docker-reboot-monitor` vs `process-restart-monitor`)
- State files (`/var/tmp/docker-restartcount.state` vs `/var/tmp/process-restartcount.state`)
- Scripts (`/usr/local/bin/docker-reboot-monitor.sh` vs `/usr/local/bin/process-restart-monitor.sh`)

---

## 📜 License

MIT License © 2025
Created by [guo](https://github.com/guo)

---

### ⭐️ Why This Exists

Most observability stacks are heavy and overkill for small setups.
These tiny scripts fill the gap: **just tell me when something restarts.**
