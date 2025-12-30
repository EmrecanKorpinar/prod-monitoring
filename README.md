# 🚀 Enterprise Production Monitoring System

A comprehensive enterprise-grade monitoring and alerting system with real-time metrics, process health monitoring, advanced logging, security auditing, and auto-restart capabilities.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Enabled-blue)](https://www.docker.com/)
[![Prometheus](https://img.shields.io/badge/Prometheus-Compatible-orange)](https://prometheus.io/)

## ✨ Features

### 📊 Real-Time System Monitoring
- **Comprehensive Metrics**: CPU, Memory, Disk, Load Average, Network I/O, Process Count, System Uptime
- **Dual Format Export**: JSON and CSV for maximum compatibility
- **Historical Tracking**: Trend analysis with configurable retention
- **Prometheus Integration**: Native metrics export for Grafana dashboards

### 🏥 Process Health Monitoring
- **Service Status Tracking**: Monitor nginx, MySQL, Redis, Docker containers
- **Port Availability**: Real-time port scanning and validation
- **Container Health**: Docker container status, uptime, and restart count
- **Auto-Recovery**: Automatic service restart on failure (systemd integration)

### 📝 Advanced Logging System
- **Structured Logging**: Winston logger with JSON format
- **HTTP Request Tracking**: Morgan middleware for all API calls
- **Daily Log Rotation**: Automatic cleanup with 7-day retention
- **Multi-Level Logs**: Info, Warning, Error, Critical severity levels
- **System Log Analysis**: Integration with syslog, dmesg, journalctl

### 🚨 Intelligent Alerting
- **Multi-Level Alerts**: WARNING (85%) and CRITICAL (90%) thresholds
- **Flood Prevention**: 10-minute cooldown between duplicate alerts
- **Multiple Channels**:
  - Email notifications (via SMTP)
  - Slack webhooks
  - Custom webhook integration
- **Smart Monitoring**: CPU, Memory, Disk, Load Average, Process health

### 🔒 Security & Auditing
- **Role-Based Access Control (RBAC)**: Admin, Developer, Read-only roles
- **API Token Authentication**: Secure token-based API access
- **Audit Logging**: Complete trail of who did what and when
- **SSH Key Management**: Password-less authentication setup
- **Sudo Policy**: Restricted command execution
- **Security Scanning**: Unauthorized port detection, failed login monitoring
- **Auth Log Analysis**: SSH brute force attempt detection

### 🎨 Web Dashboard
- **Modern UI**: Beautiful, responsive dashboard with real-time updates
- **Live Charts**: Trend visualization with Chart.js
- **Auto-Refresh**: Updates every 30 seconds
- **Color-Coded Metrics**: Green/Yellow/Red status indicators
- **Mobile-Friendly**: Responsive design for all devices

### 🔄 Auto-Restart & High Availability
- **Systemd Integration**: Service management and auto-restart
- **Watchdog Script**: Self-healing monitoring of the monitoring system
- **Docker Health Checks**: Container-level health validation
- **Graceful Restart**: Zero-downtime deployments

### 📈 Application Metrics
- **Response Time Tracking**: Monitor API performance
- **Error Rate Analysis**: Track application errors
- **Throughput Monitoring**: Requests per minute
- **Active Connections**: Real-time connection tracking

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Systemd Auto-Restart                    │
│              (prod-monitoring.service)                      │
└───────────────────────┬─────────────────────────────────────┘
                        │
            ┌───────────▼───────────┐
            │   NGINX Load Balancer │  :8080
            │  (Reverse Proxy)      │
            └───────────┬───────────┘
                        │
           ┌────────────┼────────────┐
           │                         │
    ┌──────▼──────┐          ┌──────▼──────┐
    │  Backend 1  │          │  Backend 2  │  Node.js + Express
    │   :3000     │          │   :3000     │  Winston + Morgan
    └──────┬──────┘          └──────┬──────┘  Prometheus Metrics
           │                         │          RBAC + JWT
           └────────────┬────────────┘
                        │
        ┌───────────────▼────────────────┐
        │      Monitoring Scripts         │
        │  ┌──────────────────────────┐  │
        │  │ • metrics.sh (5min)      │  │
        │  │ • alert_engine.sh (1min) │  │  Systemd Timers
        │  │ • process_health.sh      │  │  Auto-Scheduled
        │  │ • system_logs.sh         │  │
        │  │ • port_scan.sh           │  │
        │  │ • log_manager.sh         │  │
        │  └──────────────────────────┘  │
        └───────────────┬────────────────┘
                        │
        ┌───────────────▼────────────────┐
        │       Data Directory            │
        │  ┌──────────────────────────┐  │
        │  │ • metrics.csv/json       │  │
        │  │ • alerts.log             │  │  Rotating Logs
        │  │ • security.log           │  │  7-Day Retention
        │  │ • process_health.json    │  │
        │  │ • system_analysis.log    │  │
        │  │ • audit.log              │  │
        │  │ • app-YYYY-MM-DD.log     │  │
        │  └──────────────────────────┘  │
        └─────────────────────────────────┘
                        │
        ┌───────────────▼────────────────┐
        │    External Integrations        │
        │  • Prometheus/Grafana           │
        │  • Slack/Email Alerts           │
        │  • Webhooks                     │
        └─────────────────────────────────┘
```

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-----------|
| Infrastructure | Docker, Docker Compose, Systemd |
| Load Balancer | NGINX |
| Backend | Node.js, Express.js |
| Logging | Winston, Morgan, Daily-Rotate-File |
| Metrics | Prometheus Client, prom-client |
| Authentication | JWT, bcrypt |
| Monitoring Scripts | Bash, jq, nc, systemctl, journalctl |
| Dashboard | HTML5, CSS3, JavaScript, Chart.js |
| Alerts | Nodemailer, Slack Webhooks |
| OS | Linux (Ubuntu/Debian) |

## 📦 Quick Start

### Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y docker.io docker-compose git curl jq netcat-openbsd

# Start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### Installation

```bash
# 1. Clone repository
git clone https://github.com/EmrecanKorpinar/prod-monitoring.git
cd prod-monitoring

# 2. Make scripts executable
chmod +x scripts/*.sh

# 3. Start services
docker-compose up -d

# 4. Run initial monitoring
./scripts/monitor.sh

# 5. Open dashboard
python3 -m http.server 8000
# Visit: http://localhost:8000/dashboard.html
```

### Systemd Setup (Production)

```bash
# Copy service files
sudo cp systemd/*.service /etc/systemd/system/
sudo cp systemd/*.timer /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable auto-restart
sudo systemctl enable prod-monitoring.service
sudo systemctl start prod-monitoring.service

# Enable timers
sudo systemctl enable metrics-collector.timer alert-engine.timer
sudo systemctl start metrics-collector.timer alert-engine.timer

# Check status
sudo systemctl status prod-monitoring.service
systemctl list-timers
```

See [docs/SYSTEMD_SETUP.md](docs/SYSTEMD_SETUP.md) for detailed configuration.

## 🎯 Usage

### Manual Monitoring

```bash
# Collect system metrics
./scripts/metrics.sh

# Check process health
./scripts/process_health.sh

# Analyze system logs
./scripts/system_logs.sh

# Run security scan
./scripts/port_scan.sh

# Check alerts
./scripts/alert_engine_v2.sh

# Full monitoring cycle
./scripts/monitor.sh
```

### API Endpoints

```bash
# Public endpoints (no authentication)
curl http://localhost:8080/health
curl http://localhost:8080/api/info
curl http://localhost:8080/metrics/prometheus

# Authenticated endpoints (require X-API-Token header)
curl -H "X-API-Token: admin-token-123" http://localhost:8080/metrics
curl -H "X-API-Token: admin-token-123" http://localhost:8080/health/processes
curl -H "X-API-Token: admin-token-123" http://localhost:8080/alerts
curl -H "X-API-Token: admin-token-123" http://localhost:8080/security
curl -H "X-API-Token: admin-token-123" http://localhost:8080/metrics/application

# Admin-only endpoints
curl -H "X-API-Token: admin-token-123" http://localhost:8080/logs/system
curl -H "X-API-Token: admin-token-123" http://localhost:8080/logs/audit
```

### Configure Alerts

```bash
# Email alerts
export EMAIL_ENABLED=true
export EMAIL_TO="admin@example.com"
export EMAIL_FROM="monitoring@example.com"

# Slack alerts
export SLACK_ENABLED=true
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Run alert engine
./scripts/alert_engine_v2.sh
```

## 🔧 Configuration

### Alert Thresholds

Edit [scripts/alert_engine_v2.sh](scripts/alert_engine_v2.sh):
```bash
# CPU thresholds
CPU_WARNING=85
CPU_CRITICAL=90

# Memory thresholds
MEM_WARNING=85
MEM_CRITICAL=95

# Disk thresholds
DISK_WARNING=85
DISK_CRITICAL=95
```

### Log Retention

Edit [scripts/log_manager.sh](scripts/log_manager.sh):
```bash
MAX_LOG_SIZE=10485760  # 10MB
MAX_LOG_AGE=7          # 7 days
```

### API Tokens

⚠️ **IMPORTANT**: Change default tokens in production!

Edit [backend/index-v2.js](backend/index-v2.js):
```javascript
const API_USERS = {
  "admin": { role: "admin", token: "YOUR-SECURE-TOKEN-HERE" },
  "developer": { role: "developer", token: "YOUR-DEV-TOKEN-HERE" },
  "readonly": { role: "readonly", token: "YOUR-READONLY-TOKEN-HERE" }
};
```

Generate secure tokens:
```bash
openssl rand -hex 32
```

## 📁 Project Structure

```
prod-monitoring/
├── backend/
│   ├── Dockerfile
│   ├── index.js              # Original backend
│   ├── index-v2.js           # Enhanced backend with RBAC
│   ├── package.json
│   └── nginx.conf
├── nginx/
│   └── nginx.conf            # Load balancer configuration
├── scripts/
│   ├── metrics.sh            # System metrics collection
│   ├── alert_engine.sh       # Basic alerting
│   ├── alert_engine_v2.sh    # Advanced alerting (Email/Slack)
│   ├── port_scan.sh          # Security port scanning
│   ├── log_manager.sh        # Log rotation & cleanup
│   ├── process_health.sh     # Process health monitoring
│   ├── system_logs.sh        # System log analysis
│   └── monitor.sh            # Orchestration script
├── systemd/
│   ├── prod-monitoring.service
│   ├── metrics-collector.service
│   ├── metrics-collector.timer
│   ├── alert-engine.service
│   └── alert-engine.timer
├── data/                     # All logs and metrics
│   ├── metrics.csv
│   ├── metrics.json
│   ├── alerts.log
│   ├── security.log
│   ├── process_health.json
│   ├── system_analysis.log
│   ├── audit.log
│   ├── app-YYYY-MM-DD.log
│   └── state/                # Alert cooldown states
├── docs/
│   ├── SECURITY.md           # Security and RBAC guide
│   └── SYSTEMD_SETUP.md      # Systemd configuration
├── dashboard.html            # Web monitoring UI
├── docker-compose.yml
└── README.md
```

## 🔍 Monitoring Capabilities

### System Metrics
- CPU Usage (%)
- Memory Usage (%)
- Disk Usage (%)
- Load Average (1/5/15 min)
- Process Count
- System Uptime
- Network RX/TX bytes

### Process Health
- Docker container status
- systemd service status
- Port availability check
- Container restart count
- Service uptime tracking

### Application Metrics
- Total requests count
- Average response time
- Error rate (%)
- Requests per minute
- Active connections
- HTTP status code distribution

### Security Monitoring
- Unauthorized port detection
- Failed SSH login attempts
- Successful root logins
- Sudo command usage
- Docker container tracking

### System Logs
- Journal errors and warnings
- Kernel messages (dmesg)
- Syslog analysis
- Authentication logs
- Critical service failures
- OOM (Out of Memory) events
- Filesystem errors

## 🚨 Alerting Conditions

| Metric | WARNING | CRITICAL |
|--------|---------|----------|
| CPU | > 85% | > 90% |
| Memory | > 85% | > 95% |
| Disk | > 85% | > 95% |
| Load | > 2x CPUs | > 3x CPUs |
| Services | Any non-critical down | Critical service down |
| Containers | 1-2 down | All down |

## 🔐 Security

See [docs/SECURITY.md](docs/SECURITY.md) for comprehensive security configuration including:

- SSH key management
- Sudo policy configuration
- RBAC implementation
- API token management
- Audit logging
- Firewall setup
- SSL/TLS configuration
- Security best practices

### Quick Security Checklist

- [ ] Change all default API tokens
- [ ] Set up SSH key authentication
- [ ] Disable password authentication
- [ ] Configure sudo policies
- [ ] Enable UFW firewall
- [ ] Set up SSL/TLS
- [ ] Configure log rotation
- [ ] Enable audit logging
- [ ] Set up fail2ban
- [ ] Regular security audits

## 📊 Prometheus & Grafana Integration

### Prometheus Setup

```bash
# Start Prometheus
docker run -d -p 9090:9090 \
  -v $PWD/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus
```

**prometheus.yml**:
```yaml
scrape_configs:
  - job_name: 'prod-monitoring'
    static_configs:
      - targets: ['host.docker.internal:8080']
    metrics_path: '/metrics/prometheus'
```

### Grafana Dashboard

```bash
# Start Grafana
docker run -d -p 3000:3000 grafana/grafana

# Access: http://localhost:3000 (admin/admin)
```

1. Add Prometheus data source: `http://prometheus:9090`
2. Import dashboard ID: 1860 (Node Exporter)
3. Create custom dashboards

## 🐛 Troubleshooting

### Logs Not Appearing

```bash
# Check permissions
chmod +x scripts/*.sh
mkdir -p data
chmod 755 data

# Verify paths in scripts
grep -r "/home/emrecan/home/prod-monitoring" scripts/
```

### Docker Containers Won't Start

```bash
# Check logs
docker-compose logs

# Rebuild
docker-compose down
docker-compose up -d --build
```

### Alerts Not Sending

```bash
# Check alert state
ls -la data/state/

# Reset cooldown
rm data/state/*.state

# Test email
echo "Test" | mail -s "Test Alert" your@email.com

# Test Slack webhook
curl -X POST $SLACK_WEBHOOK_URL -H 'Content-Type: application/json' -d '{"text":"Test"}'
```

### Systemd Service Failures

```bash
# Check status
sudo systemctl status prod-monitoring.service

# View logs
sudo journalctl -xeu prod-monitoring.service

# Manual test
cd /home/emrecan/home/prod-monitoring
docker-compose up
```

## 📈 Performance Optimization

### Resource Limits

Edit `docker-compose.yml`:
```yaml
services:
  backend1:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

### Log Optimization

```bash
# Compress old logs
find data/ -name "*.log" -mtime +7 -exec gzip {} \;

# Clear old rotated logs
find data/ -name "*.gz" -mtime +30 -delete
```

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

MIT License - see [LICENSE](LICENSE) file

## 👤 Author

**EmrecanKorpinar**

- GitHub: [@EmrecanKorpinar](https://github.com/EmrecanKorpinar)
- Project: [prod-monitoring](https://github.com/EmrecanKorpinar/prod-monitoring)

## 🙏 Acknowledgments

- Winston for excellent logging
- Prometheus for metrics standard
- Chart.js for beautiful charts
- Docker for containerization
- Systemd for service management

---

**⭐ If you find this project useful, please consider giving it a star!**

**Made with ❤️ for reliable production monitoring**
