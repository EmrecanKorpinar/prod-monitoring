# Security and Access Control Configuration

## SSH Key Management

### Generate SSH Key Pair
```bash
# On your local machine
ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/prod_monitoring

# Copy public key to server
ssh-copy-id -i ~/.ssh/prod_monitoring.pub user@server
```

### Server-side Configuration
```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config

# Recommended settings:
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
MaxAuthTries 3
LoginGraceTime 60

# Restart SSH
sudo systemctl restart sshd
```

### Manage Authorized Keys
```bash
# Add key
echo "ssh-ed25519 AAAA... user@host" >> ~/.ssh/authorized_keys

# Set permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

## Sudo Policy

### Create sudoers file for monitoring
```bash
sudo visudo -f /etc/sudoers.d/monitoring

# Add these lines (replace 'username' with actual user):
username ALL=(ALL) NOPASSWD: /usr/bin/docker ps
username ALL=(ALL) NOPASSWD: /usr/bin/docker logs
username ALL=(ALL) NOPASSWD: /usr/bin/docker inspect
username ALL=(ALL) NOPASSWD: /usr/bin/systemctl status *
username ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart prod-monitoring
username ALL=(ALL) NOPASSWD: /usr/bin/journalctl
username ALL=(ALL) NOPASSWD: /usr/sbin/dmesg
username ALL=(ALL) NOPASSWD: /home/emrecan/home/prod-monitoring/scripts/*.sh

# Set permissions
sudo chmod 440 /etc/sudoers.d/monitoring
```

## Role-Based Access Control (RBAC)

### API Token Management

The system supports three roles:

1. **Admin** - Full access to all endpoints
   - Token: `admin-token-123` (change in production!)
   - Can access: /logs/system, /logs/audit, all other endpoints

2. **Developer** - Read/write access to metrics and alerts
   - Token: `dev-token-456`
   - Can access: /metrics, /alerts, /health/processes

3. **Read-only** - View-only access
   - Token: `readonly-token-789`
   - Can access: /metrics, /health

### Usage

```bash
# Make API request with authentication
curl -H "X-API-Token: admin-token-123" http://localhost:8080/metrics

# Example with jq for JSON formatting
curl -H "X-API-Token: admin-token-123" http://localhost:8080/logs/audit | jq
```

### Production Deployment

**IMPORTANT**: Change default tokens before production deployment!

```bash
# Set environment variables
export JWT_SECRET="your-very-secure-random-string-here"
export ADMIN_TOKEN="$(openssl rand -hex 32)"
export DEV_TOKEN="$(openssl rand -hex 32)"
export READONLY_TOKEN="$(openssl rand -hex 32)"

# Save tokens securely
echo "Admin Token: $ADMIN_TOKEN" >> /secure/location/tokens.txt
echo "Developer Token: $DEV_TOKEN" >> /secure/location/tokens.txt
echo "ReadOnly Token: $READONLY_TOKEN" >> /secure/location/tokens.txt

# Restrict permissions
chmod 600 /secure/location/tokens.txt
```

### Update backend/index-v2.js with new tokens

Replace the `API_USERS` object with your generated tokens.

## Audit Logging

All API requests are logged to `/data/audit.log` with:
- Timestamp
- User (from token)
- HTTP Method
- Request Path
- IP Address
- User Agent

### Query Audit Logs

```bash
# View recent audit logs
tail -100 /home/emrecan/home/prod-monitoring/data/audit.log | jq

# Find specific user activity
cat /home/emrecan/home/prod-monitoring/data/audit.log | jq 'select(.user=="admin")'

# Find failed authentication attempts
grep "401" /home/emrecan/home/prod-monitoring/data/app-*.log

# Monitor audit logs in real-time
tail -f /home/emrecan/home/prod-monitoring/data/audit.log | jq
```

## File Permissions

### Recommended permissions
```bash
# Scripts should be executable by owner only
chmod 700 /home/emrecan/home/prod-monitoring/scripts/*.sh

# Data directory should be restricted
chmod 750 /home/emrecan/home/prod-monitoring/data
chmod 640 /home/emrecan/home/prod-monitoring/data/*.log

# Config files should be read-only
chmod 644 /home/emrecan/home/prod-monitoring/docker-compose.yml
chmod 644 /home/emrecan/home/prod-monitoring/nginx/nginx.conf
```

## Firewall Configuration

### UFW (Ubuntu/Debian)
```bash
# Enable firewall
sudo ufw enable

# Allow SSH (change port if needed)
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow monitoring dashboard
sudo ufw allow 8080/tcp

# Rate limit SSH
sudo ufw limit ssh

# Check status
sudo ufw status verbose
```

## SSL/TLS Configuration

### Generate self-signed certificate (for testing)
```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/monitoring.key \
  -out /etc/ssl/certs/monitoring.crt
```

### Update nginx.conf for HTTPS
```nginx
server {
    listen 443 ssl;
    ssl_certificate /etc/ssl/certs/monitoring.crt;
    ssl_certificate_key /etc/ssl/private/monitoring.key;
    
    # Strong SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # ... rest of config
}
```

## Security Best Practices

1. **Change all default tokens** before production deployment
2. **Use SSH keys** instead of passwords
3. **Limit sudo access** to specific commands only
4. **Enable UFW firewall** and restrict ports
5. **Use HTTPS** for dashboard and API
6. **Regularly review audit logs** for suspicious activity
7. **Keep systems updated**: `sudo apt update && sudo apt upgrade`
8. **Use fail2ban** to block brute force attempts
9. **Set up log rotation** to prevent disk fill
10. **Backup data directory** regularly

## Monitoring Security Events

```bash
# Monitor failed login attempts
sudo journalctl -u ssh -f | grep "Failed"

# Check for unauthorized sudo usage
sudo journalctl -f | grep sudo

# Monitor audit log for suspicious activity
tail -f /home/emrecan/home/prod-monitoring/data/audit.log | \
  jq 'select(.method=="DELETE" or .method=="POST")'

# Check for port scans
sudo journalctl -k | grep "Firewall"
```

## Emergency Response

### If system is compromised:

1. **Disconnect from network**
```bash
sudo ip link set eth0 down
```

2. **Check running processes**
```bash
ps auxf
netstat -tulpn
```

3. **Review logs**
```bash
sudo journalctl --since "1 hour ago"
cat /home/emrecan/home/prod-monitoring/data/audit.log
```

4. **Rotate all tokens**
5. **Update SSH authorized_keys**
6. **Review and update firewall rules**
