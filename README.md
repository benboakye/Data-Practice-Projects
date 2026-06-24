sudo systemctl stop nid-auto-capture 2>/dev/null || true
sudo systemctl disable nid-auto-capture 2>/dev/null || true
sudo rm -f /etc/systemd/system/nid-auto-capture.service
sudo rm -f /usr/local/bin/nid-auto-capture-start.sh
sudo systemctl daemon-reload
sudo systemctl reset-failed
