#!/bin/bash

# Alert Engine with Email and Slack Support
LOG_DIR="/home/emrecan/home/prod-monitoring/data"
STATE_DIR="$LOG_DIR/state"
mkdir -p "$STATE_DIR"

COOLDOWN=600  # 10 dakika
NOW=$(date +%s)

# Email configuration (optional)
EMAIL_ENABLED=${EMAIL_ENABLED:-false}
EMAIL_TO=${EMAIL_TO:-"admin@example.com"}
EMAIL_FROM=${EMAIL_FROM:-"monitoring@example.com"}

# Slack configuration (optional)
SLACK_ENABLED=${SLACK_ENABLED:-false}
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-""}

# Send email function
send_email() {
    local subject="$1"
    local message="$2"
    
    if [ "$EMAIL_ENABLED" = true ]; then
        echo "$message" | mail -s "$subject" "$EMAIL_TO"
        logger.info "Email sent: $subject"
    fi
}

# Send Slack notification
send_slack() {
    local level="$1"
    local message="$2"
    
    if [ "$SLACK_ENABLED" = true ] && [ -n "$SLACK_WEBHOOK_URL" ]; then
        local color="danger"
        local emoji=":rotating_light:"
        
        case "$level" in
            "CRITICAL") color="danger"; emoji=":red_circle:" ;;
            "WARNING") color="warning"; emoji=":warning:" ;;
            "INFO") color="good"; emoji=":information_source:" ;;
        esac
        
        curl -X POST "$SLACK_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"title\": \"$emoji Production Monitoring Alert\",
                    \"text\": \"*Level:* $level\n*Message:* $message\",
                    \"footer\": \"$(hostname)\",
                    \"ts\": $(date +%s)
                }]
            }" 2>/dev/null
    fi
}

# Alert fonksiyonu
send_alert() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Log'a yaz
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/alerts.log"
    
    # Konsola çıktı
    echo "⚠️  ALERT [$level]: $message"
    
    # Email gönder (CRITICAL ve WARNING için)
    if [ "$level" = "CRITICAL" ] || [ "$level" = "WARNING" ]; then
        send_email "[${level}] Production Alert - $(hostname)" "$message\n\nTimestamp: $timestamp\nHost: $(hostname)"
        send_slack "$level" "$message"
    fi
    
    # Webhook gönder
    if [ -n "$WEBHOOK_URL" ]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"level\":\"$level\",\"message\":\"$message\",\"timestamp\":\"$timestamp\",\"hostname\":\"$(hostname)\"}" \
            2>/dev/null
    fi
}

# Cooldown kontrolü
check_cooldown() {
    local state_file="$1"
    [ ! -f "$state_file" ] && echo 0 > "$state_file"
    local last=$(cat "$state_file")
    
    if (( NOW - last > COOLDOWN )); then
        echo "$NOW" > "$state_file"
        return 0
    fi
    return 1
}

# CPU kontrolü
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d. -f1)
if [ "$CPU" -gt 90 ]; then
    if check_cooldown "$STATE_DIR/cpu_critical.state"; then
        send_alert "CRITICAL" "CPU usage at ${CPU}% - System overload! Immediate action required."
    fi
elif [ "$CPU" -gt 85 ]; then
    if check_cooldown "$STATE_DIR/cpu_warning.state"; then
        send_alert "WARNING" "CPU usage at ${CPU}%"
    fi
fi

# Memory kontrolü
MEM=$(free | awk '/Mem/ {printf("%.0f"), $3/$2 * 100}')
if [ "$MEM" -gt 95 ]; then
    if check_cooldown "$STATE_DIR/mem_critical.state"; then
        send_alert "CRITICAL" "Memory usage at ${MEM}% - OOM risk! Consider restarting services."
    fi
elif [ "$MEM" -gt 85 ]; then
    if check_cooldown "$STATE_DIR/mem_warning.state"; then
        send_alert "WARNING" "Memory usage at ${MEM}%"
    fi
fi

# Disk kontrolü
DISK=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK" -gt 95 ]; then
    if check_cooldown "$STATE_DIR/disk_critical.state"; then
        send_alert "CRITICAL" "Disk usage at ${DISK}% - Running out of space! Cleanup required."
    fi
elif [ "$DISK" -gt 85 ]; then
    if check_cooldown "$STATE_DIR/disk_warning.state"; then
        send_alert "WARNING" "Disk usage at ${DISK}%"
    fi
fi

# Load average kontrolü
LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//' | cut -d. -f1)
CPU_COUNT=$(nproc)
if [ "$LOAD" -gt $((CPU_COUNT * 2)) ]; then
    if check_cooldown "$STATE_DIR/load_alert.state"; then
        send_alert "WARNING" "High load average: $LOAD (CPUs: $CPU_COUNT)"
    fi
fi

# Process health kontrolü
if [ -f "$LOG_DIR/process_health.json" ]; then
    critical_down=$(jq -r '.summary.critical_services_down' "$LOG_DIR/process_health.json" 2>/dev/null || echo "0")
    if [ "$critical_down" = "1" ]; then
        if check_cooldown "$STATE_DIR/process_critical.state"; then
            send_alert "CRITICAL" "Critical services are down! Check process health immediately."
        fi
    fi
fi

# Docker container kontrolü
if command -v docker &> /dev/null; then
    expected_containers=3  # nginx + 2 backends
    running=$(docker ps --filter "name=prod-monitoring" --format "{{.Names}}" 2>/dev/null | wc -l)
    
    if [ "$running" -lt "$expected_containers" ]; then
        if check_cooldown "$STATE_DIR/docker_alert.state"; then
            send_alert "WARNING" "Only $running/$expected_containers containers running!"
        fi
    fi
fi

# Disk I/O kontrolü (opsiyonel)
if command -v iostat &> /dev/null; then
    io_wait=$(iostat -c 1 2 | tail -1 | awk '{print $4}' | cut -d. -f1)
    if [ "$io_wait" -gt 50 ]; then
        if check_cooldown "$STATE_DIR/io_alert.state"; then
            send_alert "WARNING" "High I/O wait: ${io_wait}% - Possible disk bottleneck"
        fi
    fi
fi
