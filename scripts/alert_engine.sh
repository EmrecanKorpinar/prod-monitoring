#!/bin/bash

# Gelişmiş alert motoru - Çoklu seviye ve kanal desteği
LOG_DIR="/home/emrecan/home/prod-monitoring/data"
STATE_DIR="$LOG_DIR/state"
mkdir -p "$STATE_DIR"

COOLDOWN=600  # 10 dakika
NOW=$(date +%s)

# Alert fonksiyonu
send_alert() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Log'a yaz
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/alerts.log"
    
    # Konsola çıktı
    echo "⚠️  ALERT [$level]: $message"
    
    # Webhook gönder (opsiyonel)
    if [ -n "$WEBHOOK_URL" ]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"level\":\"$level\",\"message\":\"$message\",\"timestamp\":\"$timestamp\"}" \
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
if [ "$CPU" -gt 85 ]; then
    if check_cooldown "$STATE_DIR/cpu_alert.state"; then
        if [ "$CPU" -gt 95 ]; then
            send_alert "CRITICAL" "CPU usage at ${CPU}% - System overload!"
        else
            send_alert "WARNING" "CPU usage at ${CPU}%"
        fi
    fi
fi

# Memory kontrolü
MEM=$(free | awk '/Mem/ {printf("%.0f"), $3/$2 * 100}')
if [ "$MEM" -gt 85 ]; then
    if check_cooldown "$STATE_DIR/mem_alert.state"; then
        if [ "$MEM" -gt 95 ]; then
            send_alert "CRITICAL" "Memory usage at ${MEM}% - OOM risk!"
        else
            send_alert "WARNING" "Memory usage at ${MEM}%"
        fi
    fi
fi

# Disk kontrolü
DISK=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK" -gt 85 ]; then
    if check_cooldown "$STATE_DIR/disk_alert.state"; then
        if [ "$DISK" -gt 95 ]; then
            send_alert "CRITICAL" "Disk usage at ${DISK}% - Running out of space!"
        else
            send_alert "WARNING" "Disk usage at ${DISK}%"
        fi
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
