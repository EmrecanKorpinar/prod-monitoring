# Production Monitoring System

A comprehensive production-grade monitoring and alerting system with real-time dashboard, advanced logging, and security scanning.

## 🚀 Features

### System Monitoring
- **Real-time Metrics Collection**: CPU, Memory, Disk, Load Average, Network, Processes
- **JSON & CSV Export**: Dual format for compatibility and analysis
- **Historical Data**: Track trends over time

### Advanced Logging
- **Winston Logger**: Structured logging with rotation
- **Morgan HTTP Logger**: Request/response tracking
- **Daily Log Rotation**: Automatic cleanup (7-day retention)
- **Multi-level Logging**: Info, Warning, Error, Critical
- **Centralized Log Management**: All logs in `/data` directory

### Intelligent Alerting
- **Multi-level Alerts**: WARNING and CRITICAL thresholds
- **Alert Flood Prevention**: 10-minute cooldown between alerts
- **Multiple Metrics**: CPU, Memory, Disk, Load Average monitoring
- **Webhook Support**: Send alerts to external services (Slack, Discord, etc.)

### Security Monitoring
- **Port Scanning**: Detect unauthorized open ports
- **Failed Login Detection**: Monitor SSH brute force attempts
- **Docker Container Tracking**: Monitor running containers
- **Security Log Audit Trail**: Complete security event logging

### Dashboard
- **Real-time Visualization**: Beautiful web-based dashboard
- **Auto-refresh**: Updates every 30 seconds
- **Charts & Graphs**: Visual trend analysis with Chart.js
- **Alert Display**: Recent alerts and security events
- **Responsive Design**: Works on all devices

## 📋 Architecture

```
┌─────────────┐
│   NGINX     │  (Load Balancer & Reverse Proxy)
│   :8080     │
└──────┬──────┘
       │
       ├───────┐
       │       │
┌──────▼───┐ ┌▼──────────┐
│ Backend1 │ │ Backend2  │  (Node.js + Express)
│  :3000   │ │  :3000    │  (Winston + Morgan Logging)
└──────────┘ └───────────┘
       │
       │
┌──────▼──────────────────┐
│   Monitoring Scripts    │
│  - metrics.sh           │
│  - alert_engine.sh      │
│  - port_scan.sh         │
│  - log_manager.sh       │
└─────────────────────────┘
       │
       ▼
┌─────────────────────────┐
│    Data Directory       │
│  - metrics.csv/json     │
│  - alerts.log           │
│  - security.log         │
│  - app.log (rotated)    │
└─────────────────────────┘
```

## 🛠️ Tech Stack

- **Infrastructure**: Docker, Docker Compose
- **Web Server**: NGINX (Reverse Proxy & Load Balancing)
- **Backend**: Node.js, Express.js
- **Logging**: Winston, Morgan, Daily Rotate File
- **Monitoring**: Bash scripts (metrics, alerts, security)
- **Dashboard**: HTML5, CSS3, JavaScript, Chart.js
- **OS**: Linux (Ubuntu/Debian)

## 📦 Installation

1. **Clone the repository**
```bash
git clone https://github.com/EmrecanKorpinar/prod-monitoring.git
cd prod-monitoring
```

2. **Start the system**
```bash
docker-compose up -d
```

3. **Run monitoring scripts**
```bash
chmod +x scripts/*.sh
./scripts/monitor.sh
```

4. **Open Dashboard**
```bash
# Open dashboard.html in your browser
# Or serve it with:
python3 -m http.server 8000
# Then visit: http://localhost:8000/dashboard.html
```

## 🎯 Usage

### Manual Monitoring
```bash
# Collect metrics
./scripts/metrics.sh

# Check alerts
./scripts/alert_engine.sh

# Security scan
./scripts/port_scan.sh

# Manage logs
./scripts/log_manager.sh

# Run full monitoring cycle
./scripts/monitor.sh
```

### Automated Monitoring with Cron
```bash
# Add to crontab
crontab -e

# Run metrics every 5 minutes
*/5 * * * * /home/emrecan/home/prod-monitoring/scripts/metrics.sh

# Check alerts every minute
* * * * * /home/emrecan/home/prod-monitoring/scripts/alert_engine.sh

# Security scan every hour
0 * * * * /home/emrecan/home/prod-monitoring/scripts/port_scan.sh

# Log rotation daily
0 0 * * * /home/emrecan/home/prod-monitoring/scripts/log_manager.sh
```

### API Endpoints

The backend provides REST API endpoints:

```bash
# Health check
curl http://localhost:8080/health

# Get metrics (last 100 entries)
curl http://localhost:8080/metrics

# Get alerts (last 50)
curl http://localhost:8080/alerts

# Get security logs (last 50)
curl http://localhost:8080/security
```

### Webhook Alerts

Set environment variable for webhook notifications:

```bash
export WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
./scripts/alert_engine.sh
```

## 📊 Dashboard Features

- **Live Metrics**: CPU, Memory, Disk, Load, Processes, Uptime
- **Trend Charts**: Last 20 samples visualized
- **Color-coded Alerts**: 
  - 🟢 Green: < 75%
  - 🟡 Yellow: 75-90%
  - 🔴 Red: > 90%
- **Auto-refresh**: Every 30 seconds
- **Responsive Layout**: Mobile-friendly

## 🔧 Configuration

### Alert Thresholds
Edit `scripts/alert_engine.sh`:
```bash
CPU_WARNING=85
CPU_CRITICAL=95
MEM_WARNING=85
MEM_CRITICAL=95
DISK_WARNING=85
DISK_CRITICAL=95
```

### Log Retention
Edit `scripts/log_manager.sh`:
```bash
MAX_LOG_SIZE=10485760  # 10MB
MAX_LOG_AGE=7          # 7 days
```

### Allowed Ports
Edit `scripts/port_scan.sh`:
```bash
ALLOWED=(22 80 443 3000 8080)
```

## 📁 Directory Structure

```
prod-monitoring/
├── backend/
│   ├── Dockerfile
│   ├── index.js           # Express app with Winston logging
│   ├── package.json
│   └── nginx.conf
├── nginx/
│   └── nginx.conf         # Load balancer config
├── scripts/
│   ├── metrics.sh         # System metrics collection
│   ├── alert_engine.sh    # Multi-level alerting
│   ├── port_scan.sh       # Security scanning
│   ├── log_manager.sh     # Log rotation & cleanup
│   └── monitor.sh         # Orchestration script
├── data/                  # All logs stored here
│   ├── metrics.csv
│   ├── metrics.json
│   ├── alerts.log
│   ├── security.log
│   ├── app-YYYY-MM-DD.log
│   └── state/             # Alert state files
├── dashboard.html         # Web dashboard
├── docker-compose.yml
└── README.md
```

## 🔍 Monitoring Capabilities

### Metrics Collected
- CPU Usage (%)
- Memory Usage (%)
- Disk Usage (%)
- Load Average
- Process Count
- System Uptime
- Network RX/TX bytes

### Alert Conditions
- CPU > 85% (WARNING) / 95% (CRITICAL)
- Memory > 85% (WARNING) / 95% (CRITICAL)
- Disk > 85% (WARNING) / 95% (CRITICAL)
- Load Average > 2x CPU cores

### Security Checks
- Unauthorized port detection
- Failed SSH login attempts
- Docker container monitoring
- Real-time port scanning

## 🚨 Troubleshooting

### Logs not appearing in /data
```bash
# Check permissions
chmod +x scripts/*.sh
mkdir -p data

# Verify paths in scripts match your setup
# All scripts use: /home/emrecan/home/prod-monitoring/data
```

### Dashboard not loading data
```bash
# Ensure backend is running
docker-compose ps

# Check CORS settings
# Verify API_URL in dashboard.html matches your setup
```

### Alerts not firing
```bash
# Check cooldown state files
ls -la data/state/

# Remove state files to reset cooldown
rm data/state/*.state
```

## 📈 Future Enhancements

- [ ] PostgreSQL/MongoDB database integration
- [ ] Email alert notifications
- [ ] Slack/Discord integration
- [ ] Prometheus metrics export
- [ ] Grafana dashboard integration
- [ ] Container resource monitoring
- [ ] Custom metric plugins
- [ ] Alert rule configuration UI
- [ ] Multi-node support
- [ ] Historical data analysis

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

## 📄 License

MIT License

## 👤 Author

EmrecanKorpinar

---

**Made with ❤️ for production monitoring**
