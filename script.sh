#!/bin/bash
set -e

IFACE="ens192"
KALI_IP="192.168.10.10"
LOCAL_PCAP_DIR="/var/log/nid-agent/pcaps"
START_SCRIPT="/usr/local/bin/nid-auto-capture-start.sh"
SERVICE_FILE="/etc/systemd/system/nid-auto-capture.service"

echo "[+] Setting up automatic PCAP capture on Ubuntu-Host 1..."

sudo apt update
sudo apt install -y tcpdump

echo "[+] Cleaning old broken service if it exists..."
sudo systemctl stop nid-auto-capture 2>/dev/null || true
sudo systemctl disable nid-auto-capture 2>/dev/null || true

echo "[+] Creating PCAP directory..."
sudo mkdir -p "$LOCAL_PCAP_DIR"

echo "[+] Creating tcpdump start script..."
sudo tee "$START_SCRIPT" > /dev/null << EOF
#!/bin/bash
mkdir -p "$LOCAL_PCAP_DIR"
exec /usr/bin/tcpdump -i "$IFACE" -nn host "$KALI_IP" -G 60 -Z root -w "$LOCAL_PCAP_DIR/traffic-%Y%m%d-%H%M%S.pcap"
EOF

sudo chmod +x "$START_SCRIPT"

echo "[+] Creating systemd service..."
sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=NID Automatic Traffic Capture Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$START_SCRIPT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Reloading systemd..."
sudo systemctl daemon-reload

echo "[+] Enabling and starting capture service..."
sudo systemctl enable --now nid-auto-capture

sleep 5

echo "[+] Service status:"
sudo systemctl status nid-auto-capture --no-pager

echo
echo "[+] PCAP folder:"
sudo ls -lh "$LOCAL_PCAP_DIR"

echo
echo "[+] Done."
