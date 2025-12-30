#!/bin/bash

# Merkezi monitoring scripti - Tüm monitoring görevlerini koordine eder

SCRIPT_DIR="/home/emrecan/home/prod-monitoring/scripts"
LOG_DIR="/home/emrecan/home/prod-monitoring/data"

# Dizinleri oluştur
mkdir -p "$LOG_DIR"
mkdir -p "$LOG_DIR/state"

echo "🚀 Starting Production Monitoring System..."

# Log yöneticisini çalıştır
"$SCRIPT_DIR/log_manager.sh"

# İlk metrikleri topla
echo "📊 Collecting initial metrics..."
"$SCRIPT_DIR/metrics.sh"

# Güvenlik taraması
echo "🔒 Running security scan..."
"$SCRIPT_DIR/port_scan.sh"

# Alert kontrolü
echo "⚠️  Checking alerts..."
"$SCRIPT_DIR/alert_engine.sh"

echo "✅ Monitoring cycle completed at $(date)"
echo ""
