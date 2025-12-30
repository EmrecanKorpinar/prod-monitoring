#!/bin/bash

# Gelişmiş sistem metrikleri toplama scripti
LOG_DIR="/home/emrecan/home/prod-monitoring/data"
mkdir -p "$LOG_DIR"

# CPU kullanımı
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')

# Memory kullanımı
MEM=$(free | awk '/Mem/ {printf("%.2f"), $3/$2 * 100}')

# Disk kullanımı
DISK=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

# Network istatistikleri
RX_BYTES=$(cat /proc/net/dev | grep -E "eth0|ens|enp" | head -1 | awk '{print $2}')
TX_BYTES=$(cat /proc/net/dev | grep -E "eth0|ens|enp" | head -1 | awk '{print $10}')

# System uptime (saniye)
UPTIME=$(awk '{print $1}' /proc/uptime)

# Process sayısı
PROCESSES=$(ps aux | wc -l)

# Load average
LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

# Timestamp
TIME=$(date +"%Y-%m-%d %H:%M:%S")

# CSV formatında kaydet
echo "$TIME,$CPU,$MEM,$DISK,$LOAD,$PROCESSES,$UPTIME,$RX_BYTES,$TX_BYTES" >> "$LOG_DIR/metrics.csv"

# JSON formatında da kaydet (API için)
cat << EOF >> "$LOG_DIR/metrics.json"
{"timestamp":"$TIME","cpu":$CPU,"memory":$MEM,"disk":$DISK,"load":$LOAD,"processes":$PROCESSES,"uptime":$UPTIME,"network":{"rx":$RX_BYTES,"tx":$TX_BYTES}}
EOF
