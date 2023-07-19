#!/bin/bash
# d3vilh 19.07.2023

# Set the path to the service file
SERVICE_FILE="/etc/systemd/system/openvpn-monitor.service"

# Check if the service file exists
if [ ! -f "$SERVICE_FILE" ]; then
  # Service file does not exist, create it
  cat << EOF > $SERVICE_FILE
[Unit]
Description=OpenVPN monitor service
After=network.target

[Service]
Type=simple
ExecStart=/root/openvpn-monitor.sh
Restart=always
RestartSec=333

[Install]
WantedBy=multi-user.target
EOF

  # Create the script file
  cat << EOF > /root/openvpn-monitor.sh
#!/bin/bash

# Set the IP address of the server to ping
SERVER_IP="10.0.60.17"

# Set the number of failed ping attempts before restarting the service
MAX_FAILED_PINGS=3

# Set the interval between ping attempts in seconds
PING_INTERVAL=300

# Set the name of the openvpn-client service
SERVICE_NAME="openvpn-client@client.service"

# Initialize the failed ping counter
FAILED_PINGS=0

LOG_DIR="/var/log/openvpn-client-logs"

# Set the maximum age of log files to gzip (in days)
MAX_LOG_AGE=5

# Set the maximum age of gzipped log files to delete (in days)
MAX_GZ_LOG_AGE=10

mkdir -p $LOG_DIR
echo "\$(date): Service Started" >> $LOG_DIR/openvpn-client.restart.\$(/usr/bin/date +%m%d%y).log

# Loop indefinitely
while true; do
  # Ping the server
  ping -c 1 \$SERVER_IP > /dev/null

  # Find log files that are older than MAX_LOG_AGE days and gzip them
  find \$LOG_DIR -name "openvpn-client.restart.*.log" -type f -mtime +\$MAX_LOG_AGE -exec gzip {} \;

  # Delete gzipped log files that are older than MAX_GZ_LOG_AGE days
  find \$LOG_DIR -name "openvpn-client.restart.*.log.gz" -type f -mtime +\$MAX_GZ_LOG_AGE -delete

  # Check the return code of the ping command
  if [ \$? -eq 0 ]; then
    # Ping succeeded, reset the failed ping counter
    FAILED_PINGS=0
      echo "\$(date): Ping successful" >> \$LOG_DIR/openvpn-client.restart.\$(/usr/bin/date +%m%d%y).log
      echo "DBG: Failed pings: \$FAILED_PINGS" >> \$LOG_DIR/openvpn-client.restart.\$(/usr/bin/date +%m%d%y).log
  else
    # Ping failed, increment the failed ping counter
    FAILED_PINGS=\$((FAILED_PINGS+1))
      echo "\$(date): One ping failed" >> \$LOG_DIR/openvpn-client.restart.\$(/usr/bin/date +%m%d%y).log

    # Check if the maximum number of failed pings has been reached
    if [ \$FAILED_PINGS -ge \$MAX_FAILED_PINGS ]; then
      # Maximum number of failed pings reached, restart the service
      systemctl restart \$SERVICE_NAME
      echo "\$(date): Restarting OpenVPN-client service." >> \$LOG_DIR/openvpn-client.restart.\$(/usr/bin/date +%m%d%y).log

      # Reset the failed ping counter
      FAILED_PINGS=0
    fi
  fi

  # Wait for the next ping interval
  sleep \$PING_INTERVAL
done
EOF

  # Make the script executable
  chmod +x /root/openvpn-monitor.sh

  # Enable and start the service
  systemctl enable openvpn-monitor.service
  systemctl start openvpn-monitor.service

  echo "Service created and started."
else
  # Service file exists, print a message
  echo "Service already exists."
fi
