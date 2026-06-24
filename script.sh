#!/bin/bash
set -e

IFACE="ens192"
KALI_IP="192.168.10.10"
LOCAL_PCAP_DIR="/var/log/nid-agent/pcaps"
SERVICE_FILE="/etc/systemd/system/nid-auto-capture.service"

echo "[+] Setting up automatic PCAP capture on Ubuntu-Host 1..."

echo "[+] Installing tcpdump..."
sudo apt update
sudo apt install -y tcpdump

echo "[+] Creating PCAP directory..."
sudo mkdir -p "$LOCAL_PCAP_DIR"
sudo chown root:root "$LOCAL_PCAP_DIR"

echo "[+] Creating systemd capture service..."
sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=NID Automatic Traffic Capture Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/tcpdump -i $IFACE -nn host $KALI_IP -G 60 -w $LOCAL_PCAP_DIR/traffic-%Y%m%d-%H%M%S.pcap
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Reloading systemd..."
sudo systemctl daemon-reload

echo "[+] Enabling and starting automatic capture..."
sudo systemctl enable --now nid-auto-capture

echo "[+] Service status:"
sudo systemctl status nid-auto-capture --no-pager

echo
echo "[+] Done. Ubuntu-Host 1 is now automatically capturing Kali traffic."
echo "[+] PCAP files will be saved in:"
echo "    $LOCAL_PCAP_DIR"
