#!/bin/bash
set -e

SERVER_USER="ubuntu"
SERVER_IP="192.168.10.50"
LOCAL_PCAP_DIR="/var/log/nid-agent/pcaps"
REMOTE_PCAP_DIR="/home/ubuntu/ML-Network-Intrusion-detection/evidence/pcaps/auto"
KEY="/root/.ssh/nid_sync_key"

SYNC_SCRIPT="/usr/local/bin/nid-sync-pcaps.sh"
SERVICE_FILE="/etc/systemd/system/nid-sync-pcaps.service"
TIMER_FILE="/etc/systemd/system/nid-sync-pcaps.timer"

echo "[+] Setting up automatic PCAP upload from Ubuntu-Host 1 to Ubuntu-Server..."

sudo apt update
sudo apt install -y openssh-client rsync

echo "[+] Creating SSH key for automatic upload..."
sudo mkdir -p /root/.ssh

if [ ! -f "$KEY" ]; then
    sudo ssh-keygen -t ed25519 -N "" -f "$KEY"
fi

sudo chmod 600 "$KEY"

echo
echo "[+] Testing SSH key login to Ubuntu-Server..."
if sudo ssh -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "echo SSH_OK" 2>/dev/null; then
    echo "[+] SSH key already works."
else
    echo
    echo "[!] SSH key is not installed on Ubuntu-Server yet."
    echo "[!] You will be asked for the Ubuntu-Server password ONCE."
    echo
    sudo ssh-copy-id -i "$KEY.pub" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP"
fi

echo "[+] Creating remote PCAP folder on Ubuntu-Server..."
sudo ssh -i "$KEY" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "mkdir -p '$REMOTE_PCAP_DIR'"

echo "[+] Creating PCAP sync script..."
sudo tee "$SYNC_SCRIPT" > /dev/null << EOF
#!/bin/bash
set -e

SERVER_USER="$SERVER_USER"
SERVER_IP="$SERVER_IP"
LOCAL_PCAP_DIR="$LOCAL_PCAP_DIR"
REMOTE_PCAP_DIR="$REMOTE_PCAP_DIR"
KEY="$KEY"
MARKER_DIR="/var/log/nid-agent/synced"

mkdir -p "\$MARKER_DIR"

LATEST=\$(ls -1t "\$LOCAL_PCAP_DIR"/*.pcap 2>/dev/null | head -1 || true)

for PCAP in "\$LOCAL_PCAP_DIR"/*.pcap; do
    [ -e "\$PCAP" ] || continue

    if [ "\$PCAP" = "\$LATEST" ]; then
        continue
    fi

    SIZE=\$(stat -c%s "\$PCAP")

    if [ "\$SIZE" -le 100 ]; then
        continue
    fi

    FILE_NAME=\$(basename "\$PCAP")
    MARKER="\$MARKER_DIR/\$FILE_NAME.uploaded"

    if [ -f "\$MARKER" ]; then
        continue
    fi

    scp -i "\$KEY" -o StrictHostKeyChecking=no "\$PCAP" "\$SERVER_USER@\$SERVER_IP:\$REMOTE_PCAP_DIR/"
    touch "\$MARKER"

    echo "[+] Uploaded \$FILE_NAME"
done
EOF

sudo chmod +x "$SYNC_SCRIPT"

echo "[+] Creating systemd sync service..."
sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=NID PCAP Upload Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$SYNC_SCRIPT
EOF

echo "[+] Creating systemd sync timer..."
sudo tee "$TIMER_FILE" > /dev/null << EOF
[Unit]
Description=Run NID PCAP Upload Every Minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Unit=nid-sync-pcaps.service

[Install]
WantedBy=timers.target
EOF

echo "[+] Reloading systemd..."
sudo systemctl daemon-reload

echo "[+] Enabling automatic PCAP upload timer..."
sudo systemctl enable --now nid-sync-pcaps.timer

echo "[+] Running first upload now..."
sudo systemctl start nid-sync-pcaps.service || true

echo
echo "[+] Timer status:"
sudo systemctl status nid-sync-pcaps.timer --no-pager

echo
echo "[+] Files now on Ubuntu-Server:"
sudo ssh -i "$KEY" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "ls -lh '$REMOTE_PCAP_DIR'"

echo
echo "[+] Done. Completed PCAP files will now upload to Ubuntu-Server automatically every minute."
