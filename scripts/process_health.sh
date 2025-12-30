#!/bin/bash

# Process Health Monitoring - Kritik servislerin sağlık kontrolü
LOG_DIR="/home/emrecan/home/prod-monitoring/data"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
STATUS_FILE="$LOG_DIR/process_health.json"

# Servis kontrolü fonksiyonu
check_service() {
    local service_name="$1"
    local check_type="$2"
    
    case $check_type in
        "systemd")
            if systemctl is-active --quiet "$service_name"; then
                echo "running"
            else
                echo "stopped"
            fi
            ;;
        "docker")
            if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${service_name}$"; then
                echo "running"
            else
                echo "stopped"
            fi
            ;;
        "process")
            if pgrep -x "$service_name" > /dev/null; then
                echo "running"
            else
                echo "stopped"
            fi
            ;;
        "port")
            local port="$3"
            if nc -z localhost "$port" 2>/dev/null; then
                echo "running"
            else
                echo "stopped"
            fi
            ;;
    esac
}

# Process bilgilerini al
get_process_info() {
    local process_name="$1"
    local pid=$(pgrep -x "$process_name" | head -1)
    
    if [ -n "$pid" ]; then
        local cpu=$(ps -p "$pid" -o %cpu --no-headers | xargs)
        local mem=$(ps -p "$pid" -o %mem --no-headers | xargs)
        local uptime=$(ps -p "$pid" -o etime --no-headers | xargs)
        echo "{\"pid\":$pid,\"cpu\":$cpu,\"memory\":$mem,\"uptime\":\"$uptime\"}"
    else
        echo "{\"pid\":0,\"cpu\":0,\"memory\":0,\"uptime\":\"0\"}"
    fi
}

# Docker container sağlık kontrolü
check_docker_health() {
    local container_name="$1"
    
    if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${container_name}$"; then
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "unknown")
        local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null)
        local uptime=$(docker inspect --format='{{.State.StartedAt}}' "$container_name" 2>/dev/null)
        local restarts=$(docker inspect --format='{{.RestartCount}}' "$container_name" 2>/dev/null || echo "0")
        
        echo "{\"status\":\"$status\",\"health\":\"$health\",\"uptime\":\"$uptime\",\"restarts\":$restarts}"
    else
        echo "{\"status\":\"stopped\",\"health\":\"unknown\",\"uptime\":\"\",\"restarts\":0}"
    fi
}

# Başlangıç
echo "[$TIMESTAMP] Starting process health check..." >> "$LOG_DIR/process_health.log"

# JSON başlat
echo "{" > "$STATUS_FILE"
echo "  \"timestamp\": \"$TIMESTAMP\"," >> "$STATUS_FILE"
echo "  \"services\": {" >> "$STATUS_FILE"

# Docker servislerini kontrol et
if command -v docker &> /dev/null; then
    echo "    \"docker_containers\": {" >> "$STATUS_FILE"
    
    # Nginx
    nginx_status=$(check_service "prod-monitoring-nginx-1" "docker")
    nginx_info=$(check_docker_health "prod-monitoring-nginx-1")
    echo "      \"nginx\": {\"status\":\"$nginx_status\",\"details\":$nginx_info}," >> "$STATUS_FILE"
    [ "$nginx_status" == "stopped" ] && echo "[$TIMESTAMP] CRITICAL: Nginx container is down!" >> "$LOG_DIR/process_health.log"
    
    # Backend services
    backend1_status=$(check_service "prod-monitoring-backend1-1" "docker")
    backend1_info=$(check_docker_health "prod-monitoring-backend1-1")
    echo "      \"backend1\": {\"status\":\"$backend1_status\",\"details\":$backend1_info}," >> "$STATUS_FILE"
    
    backend2_status=$(check_service "prod-monitoring-backend2-1" "docker")
    backend2_info=$(check_docker_health "prod-monitoring-backend2-1")
    echo "      \"backend2\": {\"status\":\"$backend2_status\",\"details\":$backend2_info}" >> "$STATUS_FILE"
    
    echo "    }," >> "$STATUS_FILE"
fi

# Sistem servisleri (MySQL, Redis, etc.)
echo "    \"system_services\": {" >> "$STATUS_FILE"

# MySQL/MariaDB
if command -v mysql &> /dev/null || command -v mariadb &> /dev/null; then
    mysql_status=$(check_service "mysql" "systemd")
    if [ "$mysql_status" == "stopped" ]; then
        mysql_status=$(check_service "mariadb" "systemd")
    fi
    echo "      \"mysql\": \"$mysql_status\"," >> "$STATUS_FILE"
    [ "$mysql_status" == "stopped" ] && echo "[$TIMESTAMP] WARNING: MySQL is not running" >> "$LOG_DIR/process_health.log"
fi

# Redis
if command -v redis-server &> /dev/null; then
    redis_status=$(check_service "redis-server" "systemd")
    if [ "$redis_status" == "stopped" ]; then
        redis_status=$(check_service "redis" "systemd")
    fi
    if [ "$redis_status" == "stopped" ]; then
        redis_status=$(check_service "redis-server" "process")
    fi
    echo "      \"redis\": \"$redis_status\"," >> "$STATUS_FILE"
    [ "$redis_status" == "stopped" ] && echo "[$TIMESTAMP] WARNING: Redis is not running" >> "$LOG_DIR/process_health.log"
fi

# SSH
ssh_status=$(check_service "ssh" "systemd")
if [ "$ssh_status" == "stopped" ]; then
    ssh_status=$(check_service "sshd" "systemd")
fi
echo "      \"ssh\": \"$ssh_status\"" >> "$STATUS_FILE"

echo "    }," >> "$STATUS_FILE"

# Port kontrolü
echo "    \"ports\": {" >> "$STATUS_FILE"
echo "      \"nginx_80\": \"$(check_service "nginx" "port" 80)\"," >> "$STATUS_FILE"
echo "      \"nginx_8080\": \"$(check_service "nginx" "port" 8080)\"," >> "$STATUS_FILE"
echo "      \"backend_3000\": \"$(check_service "backend" "port" 3000)\"," >> "$STATUS_FILE"
echo "      \"mysql_3306\": \"$(check_service "mysql" "port" 3306)\"," >> "$STATUS_FILE"
echo "      \"redis_6379\": \"$(check_service "redis" "port" 6379)\"" >> "$STATUS_FILE"
echo "    }" >> "$STATUS_FILE"

echo "  }," >> "$STATUS_FILE"

# Sistem durumu özeti
echo "  \"summary\": {" >> "$STATUS_FILE"
total_services=0
running_services=0
critical_down=0

# Docker container sayısı
if command -v docker &> /dev/null; then
    total_containers=$(docker ps -a --filter "name=prod-monitoring" --format "{{.Names}}" 2>/dev/null | wc -l)
    running_containers=$(docker ps --filter "name=prod-monitoring" --format "{{.Names}}" 2>/dev/null | wc -l)
    echo "    \"total_containers\": $total_containers," >> "$STATUS_FILE"
    echo "    \"running_containers\": $running_containers," >> "$STATUS_FILE"
    
    if [ "$nginx_status" == "stopped" ] || [ "$backend1_status" == "stopped" ]; then
        critical_down=1
    fi
fi

echo "    \"critical_services_down\": $critical_down," >> "$STATUS_FILE"
echo "    \"health_status\": \"$([ $critical_down -eq 0 ] && echo 'healthy' || echo 'unhealthy')\"" >> "$STATUS_FILE"

echo "  }" >> "$STATUS_FILE"
echo "}" >> "$STATUS_FILE"

# Konsol çıktısı
if [ $critical_down -eq 1 ]; then
    echo "🔴 Critical services are down!"
else
    echo "✅ All critical services are healthy"
fi

# JSON dosyasını loga da ekle
cat "$STATUS_FILE" >> "$LOG_DIR/process_health_history.log"
echo "" >> "$LOG_DIR/process_health_history.log"

echo "[$TIMESTAMP] Health check completed" >> "$LOG_DIR/process_health.log"
