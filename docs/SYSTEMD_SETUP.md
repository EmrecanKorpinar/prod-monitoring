# Systemd Setup and Auto-Restart Configuration

## Installation

### 1. Copy systemd service files

```bash
sudo cp /home/emrecan/home/prod-monitoring/systemd/*.service /etc/systemd/system/
sudo cp /home/emrecan/home/prod-monitoring/systemd/*.timer /etc/systemd/system/
```

### 2. Reload systemd daemon

```bash
sudo systemctl daemon-reload
```

### 3. Enable services

```bash
# Enable main monitoring service (auto-restart on failure)
sudo systemctl enable prod-monitoring.service

# Enable metrics collection timer (runs every 5 minutes)
sudo systemctl enable metrics-collector.timer
sudo systemctl start metrics-collector.timer

# Enable alert engine timer (runs every minute)
sudo systemctl enable alert-engine.timer
sudo systemctl start alert-engine.timer
```

### 4. Start the main service

```bash
sudo systemctl start prod-monitoring.service
```

## Service Management

### Check status

```bash
# Main service
sudo systemctl status prod-monitoring.service

# Timers
sudo systemctl status metrics-collector.timer
sudo systemctl status alert-engine.timer

# List all timers
systemctl list-timers
```

### View logs

```bash
# Main service logs
sudo journalctl -u prod-monitoring.service -f

# Metrics collection logs
sudo journalctl -u metrics-collector.service -f

# Alert engine logs
sudo journalctl -u alert-engine.service -f

# All monitoring logs
sudo journalctl -u 'prod-monitoring*' -u 'metrics-*' -u 'alert-*' -f
```

### Manual control

```bash
# Restart service
sudo systemctl restart prod-monitoring.service

# Stop service
sudo systemctl stop prod-monitoring.service

# Disable service
sudo systemctl disable prod-monitoring.service
```

## Auto-Restart Configuration

The `prod-monitoring.service` is configured with:

- `Restart=always` - Automatically restart on any failure
- `RestartSec=10` - Wait 10 seconds before restarting
- `StartLimitInterval=200` - Allow 5 restarts within 200 seconds
- `StartLimitBurst=5` - Maximum 5 restart attempts

### Test auto-restart

```bash
# Kill the service
sudo systemctl kill prod-monitoring.service

# Watch it restart automatically
watch -n 1 'sudo systemctl status prod-monitoring.service'
```

## Monitoring the Monitoring System

### Create watchdog script

```bash
cat > /home/emrecan/home/prod-monitoring/scripts/watchdog.sh << 'EOF'
#!/bin/bash

# Check if prod-monitoring service is running
if ! systemctl is-active --quiet prod-monitoring.service; then
    echo "$(date): prod-monitoring service is down, attempting restart"
    sudo systemctl start prod-monitoring.service
fi

# Check if containers are running
expected=3
running=$(docker ps --filter "name=prod-monitoring" --format "{{.Names}}" | wc -l)

if [ "$running" -lt "$expected" ]; then
    echo "$(date): Only $running/$expected containers running, restarting service"
    sudo systemctl restart prod-monitoring.service
fi
EOF

chmod +x /home/emrecan/home/prod-monitoring/scripts/watchdog.sh
```

### Add to crontab

```bash
crontab -e

# Add this line to run watchdog every 5 minutes
*/5 * * * * /home/emrecan/home/prod-monitoring/scripts/watchdog.sh >> /home/emrecan/home/prod-monitoring/data/watchdog.log 2>&1
```

## Email Alerts on Service Failure

### Install mailutils

```bash
sudo apt install mailutils
```

### Create OnFailure service

```bash
sudo nano /etc/systemd/system/monitoring-failure-alert@.service
```

Add:
```ini
[Unit]
Description=Send email on monitoring service failure
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo "Service %i has failed at $(date)" | mail -s "Alert: Service Failure - %i" admin@example.com'
```

### Update prod-monitoring.service

```bash
sudo nano /etc/systemd/system/prod-monitoring.service
```

Add under `[Unit]`:
```ini
OnFailure=monitoring-failure-alert@%n.service
```

Then:
```bash
sudo systemctl daemon-reload
```

## Prometheus Integration

### Install Prometheus

```bash
# Download Prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar xvfz prometheus-*.tar.gz
sudo mv prometheus-*/ /opt/prometheus/
```

### Configure Prometheus

```bash
sudo nano /opt/prometheus/prometheus.yml
```

Add:
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prod-monitoring'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/metrics/prometheus'
```

### Create Prometheus service

```bash
sudo nano /etc/systemd/system/prometheus.service
```

Add:
```ini
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/opt/prometheus/prometheus \
  --config.file=/opt/prometheus/prometheus.yml \
  --storage.tsdb.path=/opt/prometheus/data

[Install]
WantedBy=multi-user.target
```

### Start Prometheus

```bash
sudo useradd --no-create-home --shell /bin/false prometheus
sudo mkdir -p /opt/prometheus/data
sudo chown -R prometheus:prometheus /opt/prometheus
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
```

Visit: http://localhost:9090

## Grafana Setup

### Install Grafana

```bash
sudo apt-get install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo apt-get update
sudo apt-get install grafana
```

### Start Grafana

```bash
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

Visit: http://localhost:3000 (default: admin/admin)

### Add Prometheus Data Source

1. Go to Configuration → Data Sources
2. Click "Add data source"
3. Select "Prometheus"
4. URL: `http://localhost:9090`
5. Click "Save & Test"

### Import Dashboard

1. Go to Dashboards → Import
2. Use dashboard ID: 1860 (Node Exporter Full)
3. Select Prometheus data source
4. Click "Import"

## Performance Tuning

### Docker resource limits

Edit `docker-compose.yml`:

```yaml
services:
  backend1:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

### Journal log limits

```bash
sudo nano /etc/systemd/journald.conf
```

Set:
```ini
SystemMaxUse=500M
SystemMaxFileSize=50M
MaxRetentionSec=7day
```

Then:
```bash
sudo systemctl restart systemd-journald
```

## Troubleshooting

### Service won't start

```bash
# Check detailed status
sudo systemctl status prod-monitoring.service -l

# View full logs
sudo journalctl -xeu prod-monitoring.service

# Test manually
cd /home/emrecan/home/prod-monitoring
docker-compose up
```

### Timer not running

```bash
# Check timer status
systemctl list-timers --all

# View timer logs
sudo journalctl -u metrics-collector.timer

# Trigger manually
sudo systemctl start metrics-collector.service
```

### High memory usage

```bash
# Check container stats
docker stats

# Restart with memory limits
docker-compose down
docker-compose up -d --force-recreate
```
