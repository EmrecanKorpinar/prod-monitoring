#!/bin/bash

# Merkezi log yönetim sistemi
# Log dosyalarını otomatik oluşturur, rotate eder ve temizler

LOG_DIR="/home/emrecan/home/prod-monitoring/data"
MAX_LOG_SIZE=10485760  # 10MB
MAX_LOG_AGE=7  # days

# Log dizinini oluştur
mkdir -p "$LOG_DIR"

# Log dosyalarını başlat
touch "$LOG_DIR/metrics.csv"
touch "$LOG_DIR/alerts.log"
touch "$LOG_DIR/security.log"
touch "$LOG_DIR/system.log"
touch "$LOG_DIR/app.log"

# Log rotation fonksiyonu
rotate_log() {
    local logfile="$1"
    if [ -f "$logfile" ] && [ $(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile") -gt $MAX_LOG_SIZE ]; then
        timestamp=$(date +%Y%m%d_%H%M%S)
        mv "$logfile" "${logfile}.${timestamp}"
        gzip "${logfile}.${timestamp}"
        touch "$logfile"
        echo "$(date): Rotated $logfile" >> "$LOG_DIR/system.log"
    fi
}

# Eski logları temizle
cleanup_old_logs() {
    find "$LOG_DIR" -name "*.gz" -mtime +$MAX_LOG_AGE -delete
    echo "$(date): Cleaned old logs" >> "$LOG_DIR/system.log"
}

# Ana fonksiyon
main() {
    echo "$(date): Log manager started" >> "$LOG_DIR/system.log"
    
    # Tüm log dosyalarını kontrol et
    for logfile in "$LOG_DIR"/*.{log,csv}; do
        [ -f "$logfile" ] && rotate_log "$logfile"
    done
    
    cleanup_old_logs
}

main
