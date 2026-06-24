#!/bin/bash
set -e

IFACE="ens192"
KALI_IP="192.168.10.10"
LOCAL_PCAP_DIR="/var/log/nid-agent/pcaps"
SERVICE_FILE="/etc/systemd/system/nid-auto-capture.service"

echo "[+] Fixing NID automatic capture service..."

sudo mkdir -p "$LOCAL_PCAP_DIR"

sudo tee "$SERVICE_FILE" > /dev/null << SERVICE_EOF
[Unit]
Description=NID Automatic Traffic Capture Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/tcpdump -i $IFACE -nn host $KALI_IP -G 60 -Z root -w $LOCAL_PCAP_DIR/traffic-%%Y%%m%%d-%%H%%M%%S.pcap
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE_EOF

sudo systemctl daemon-reload
sudo systemctl restart nid-auto-capture

sleep 3

sudo systemctl status nid-auto-capture --no-pager
