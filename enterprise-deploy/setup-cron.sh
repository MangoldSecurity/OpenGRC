#!/bin/bash
# Set up daily Trivy vulnerability scan cron job
# Runs at 1 AM every day

set -e

echo "Setting up Trivy daily vulnerability scan cron job..."

# Create cron job file
cat > /etc/cron.d/trivy-scan << 'EOF'
# Trivy vulnerability scan - runs daily at 1 AM
0 1 * * * root /usr/local/bin/trivy-scan >> /var/log/trivy-scan.log 2>&1
EOF

# Set proper permissions on cron file
chmod 0644 /etc/cron.d/trivy-scan

# Ensure cron log file exists
touch /var/log/trivy-scan.log
chmod 644 /var/log/trivy-scan.log

echo "✓ Trivy cron job installed successfully"
echo "  Schedule: Daily at 1:00 AM"
echo "  Script: /usr/local/bin/trivy-scan"
echo "  Output: /var/www/html/public/ops/vuln.json"
echo "  Log: /var/log/trivy-scan.log"
