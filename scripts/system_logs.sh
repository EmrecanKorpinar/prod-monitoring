#!/bin/bash

# System Logs Analyzer - syslog, dmesg, journalctl üzerinden hata/uyarı takibi
LOG_DIR="/home/emrecan/home/prod-monitoring/data"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
OUTPUT_FILE="$LOG_DIR/system_analysis.log"

echo "[$TIMESTAMP] ===== System Log Analysis Started =====" >> "$OUTPUT_FILE"

# 1. Journalctl - Son 100 error ve warning
if command -v journalctl &> /dev/null; then
    echo "[$TIMESTAMP] --- Journal Errors (Last 50) ---" >> "$OUTPUT_FILE"
    journalctl -p err -n 50 --no-pager --since "1 hour ago" 2>/dev/null >> "$OUTPUT_FILE" || echo "No journal errors" >> "$OUTPUT_FILE"
    
    echo "[$TIMESTAMP] --- Journal Warnings (Last 50) ---" >> "$OUTPUT_FILE"
    journalctl -p warning -n 50 --no-pager --since "1 hour ago" 2>/dev/null >> "$OUTPUT_FILE" || echo "No journal warnings" >> "$OUTPUT_FILE"
    
    # Kritik servis hataları
    echo "[$TIMESTAMP] --- Critical Service Failures ---" >> "$OUTPUT_FILE"
    journalctl -u nginx -u mysql -u redis -u docker -p err -n 20 --no-pager --since "1 hour ago" 2>/dev/null >> "$OUTPUT_FILE"
fi

# 2. Dmesg - Kernel mesajları
if command -v dmesg &> /dev/null; then
    echo "[$TIMESTAMP] --- Kernel Errors (dmesg) ---" >> "$OUTPUT_FILE"
    dmesg --level=err,warn --time-format=iso -T 2>/dev/null | tail -50 >> "$OUTPUT_FILE" || echo "Cannot read dmesg (requires sudo)" >> "$OUTPUT_FILE"
    
    # OOM (Out of Memory) kontrolü
    oom_count=$(dmesg 2>/dev/null | grep -i "out of memory\|oom" | wc -l)
    if [ "$oom_count" -gt 0 ]; then
        echo "[$TIMESTAMP] WARNING: $oom_count OOM events detected!" >> "$OUTPUT_FILE"
        dmesg 2>/dev/null | grep -i "out of memory\|oom" | tail -10 >> "$OUTPUT_FILE"
    fi
fi

# 3. Syslog - Sistem logları
if [ -f /var/log/syslog ]; then
    echo "[$TIMESTAMP] --- Syslog Errors (Last 30 minutes) ---" >> "$OUTPUT_FILE"
    grep -i "error\|fail\|critical" /var/log/syslog 2>/dev/null | tail -50 >> "$OUTPUT_FILE" || echo "Cannot read syslog" >> "$OUTPUT_FILE"
fi

# 4. Auth log - Güvenlik
if [ -f /var/log/auth.log ]; then
    echo "[$TIMESTAMP] --- Failed Login Attempts ---" >> "$OUTPUT_FILE"
    grep "Failed password" /var/log/auth.log 2>/dev/null | tail -20 >> "$OUTPUT_FILE" || echo "No failed logins" >> "$OUTPUT_FILE"
    
    # Başarılı root loginleri
    echo "[$TIMESTAMP] --- Successful Root Logins ---" >> "$OUTPUT_FILE"
    grep "Accepted.*root" /var/log/auth.log 2>/dev/null | tail -10 >> "$OUTPUT_FILE" || echo "No root logins" >> "$OUTPUT_FILE"
    
    # Sudo kullanımı
    echo "[$TIMESTAMP] --- Recent Sudo Usage ---" >> "$OUTPUT_FILE"
    grep "sudo:" /var/log/auth.log 2>/dev/null | tail -20 >> "$OUTPUT_FILE" || echo "No sudo usage" >> "$OUTPUT_FILE"
fi

# 5. Docker logları
if command -v docker &> /dev/null; then
    echo "[$TIMESTAMP] --- Docker Container Logs (Errors) ---" >> "$OUTPUT_FILE"
    for container in $(docker ps --format "{{.Names}}" 2>/dev/null); do
        echo "  Container: $container" >> "$OUTPUT_FILE"
        docker logs --since 30m --tail 20 "$container" 2>&1 | grep -i "error\|exception\|fail" >> "$OUTPUT_FILE"
    done
fi

# 6. Disk space warnings
echo "[$TIMESTAMP] --- Disk Space Status ---" >> "$OUTPUT_FILE"
df -h >> "$OUTPUT_FILE"

disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 80 ]; then
    echo "[$TIMESTAMP] WARNING: Root disk usage at ${disk_usage}%!" >> "$OUTPUT_FILE"
    echo "  Top 10 largest directories:" >> "$OUTPUT_FILE"
    du -h / 2>/dev/null | sort -rh | head -10 >> "$OUTPUT_FILE"
fi

# 7. Sistem durumu özeti
echo "[$TIMESTAMP] --- System Status Summary ---" >> "$OUTPUT_FILE"
echo "  Uptime: $(uptime -p 2>/dev/null || uptime)" >> "$OUTPUT_FILE"
echo "  Load Average: $(uptime | awk -F'load average:' '{print $2}')" >> "$OUTPUT_FILE"
echo "  Memory: $(free -h | awk 'NR==2 {print $3 "/" $2 " (" $3/$2*100 "%)"}')" >> "$OUTPUT_FILE"
echo "  Users logged in: $(who | wc -l)" >> "$OUTPUT_FILE"

# 8. Network sorunları
echo "[$TIMESTAMP] --- Network Status ---" >> "$OUTPUT_FILE"
netstat -tulpn 2>/dev/null | grep LISTEN | head -20 >> "$OUTPUT_FILE" || ss -tulpn | grep LISTEN | head -20 >> "$OUTPUT_FILE"

# 9. Kritik dosya sistemi hataları
echo "[$TIMESTAMP] --- Filesystem Errors ---" >> "$OUTPUT_FILE"
dmesg 2>/dev/null | grep -i "ext4\|xfs\|filesystem error\|i/o error" | tail -20 >> "$OUTPUT_FILE" || echo "No filesystem errors" >> "$OUTPUT_FILE"

# 10. Cron job hataları
if [ -f /var/log/cron ]; then
    echo "[$TIMESTAMP] --- Cron Job Errors ---" >> "$OUTPUT_FILE"
    grep -i "error\|fail" /var/log/cron 2>/dev/null | tail -20 >> "$OUTPUT_FILE" || echo "No cron errors" >> "$OUTPUT_FILE"
fi

echo "[$TIMESTAMP] ===== System Log Analysis Completed =====" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Özet çıktı
echo "📋 System log analysis completed. Check $OUTPUT_FILE for details."
