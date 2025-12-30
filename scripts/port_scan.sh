#!/bin/bash

# Gelişmiş port tarama ve güvenlik kontrolü
LOG_DIR="/home/emrecan/home/prod-monitoring/data"
mkdir -p "$LOG_DIR"

ALLOWED=(22 80 443 3000 8080)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Açık portları bul
OPEN=$(ss -tuln | grep LISTEN | awk '{print $5}' | awk -F: '{print $NF}' | sort -u)

# Yetkisiz portları kontrol et
unauthorized_found=false
for port in $OPEN; do
    if [[ ! " ${ALLOWED[@]} " =~ " $port " ]]; then
        echo "[$TIMESTAMP] UNAUTHORIZED PORT: $port" >> "$LOG_DIR/security.log"
        unauthorized_found=true
    fi
done

# Tüm açık portları logla
echo "[$TIMESTAMP] Open ports: $OPEN" >> "$LOG_DIR/security.log"

# Failed SSH login denemelerini kontrol et
if [ -f /var/log/auth.log ]; then
    failed_logins=$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -10 | wc -l)
    if [ "$failed_logins" -gt 5 ]; then
        echo "[$TIMESTAMP] SECURITY: $failed_logins failed SSH attempts detected" >> "$LOG_DIR/security.log"
    fi
fi

# Docker container kontrolü
if command -v docker &> /dev/null; then
    running_containers=$(docker ps --format "{{.Names}}" 2>/dev/null | wc -l)
    echo "[$TIMESTAMP] Running containers: $running_containers" >> "$LOG_DIR/security.log"
fi

# Özet rapor
if [ "$unauthorized_found" = true ]; then
    echo "⚠️  Security scan completed - Unauthorized ports detected!"
else
    echo "✅ Security scan completed - All ports authorized"
fi
