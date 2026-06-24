#!/bin/bash
set -e

PROJECT_DIR="/home/ubuntu/ML-Network-Intrusion-detection"
MANAGER_DIR="$PROJECT_DIR/Defense System/manager"
SERVICE_FILE="/etc/systemd/system/nid-manager.service"
START_SCRIPT="/usr/local/bin/nid-manager-start.sh"

echo "[+] Setting up NID Manager auto-start service..."

if [ ! -d "$MANAGER_DIR" ]; then
    echo "[!] Manager directory not found:"
    echo "    $MANAGER_DIR"
    exit 1
fi

echo "[+] Installing required packages..."
sudo apt update
sudo apt install -y python3 python3-venv python3-pip curl

echo "[+] Preparing Python virtual environment..."
cd "$MANAGER_DIR"

if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

source venv/bin/activate
pip install -r requirements.txt
deactivate

echo "[+] Creating start script..."
sudo tee "$START_SCRIPT" > /dev/null << EOF
#!/bin/bash
cd "$MANAGER_DIR"
exec "$MANAGER_DIR/venv/bin/python" run.py
EOF

sudo chmod +x "$START_SCRIPT"

echo "[+] Creating systemd service..."
sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=NID AI Manager FastAPI Dashboard
After=network-online.target
Wants=network-online.target

[Service]
User=ubuntu
WorkingDirectory=$MANAGER_DIR
ExecStart=$START_SCRIPT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Reloading systemd..."
sudo systemctl daemon-reload

echo "[+] Stopping any old nid-manager service..."
sudo systemctl stop nid-manager 2>/dev/null || true

echo "[+] Enabling and starting nid-manager..."
sudo systemctl enable --now nid-manager

echo "[+] Waiting for service to start..."
sleep 5

echo "[+] Service status:"
sudo systemctl status nid-manager --no-pager

echo
echo "[+] Testing API:"
curl --max-time 5 http://192.168.10.50:8080/api/health || {
    echo
    echo "[!] API test failed. If you still have 'python run.py' running manually in another terminal, stop it with Ctrl+C and run:"
    echo "    sudo systemctl restart nid-manager"
    exit 1
}

echo
echo "[+] Done. NID Manager will now start automatically after reboot."
