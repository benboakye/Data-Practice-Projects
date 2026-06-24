#!/bin/bash
set -e

PROJECT_DIR="/home/ubuntu/ML-Network-Intrusion-detection"
EVIDENCE_DIR="$PROJECT_DIR/evidence"
FEATURE_DIR="$EVIDENCE_DIR/features"
EXTRACT_SCRIPT="$FEATURE_DIR/extract_pcap_features.py"
SERVICE_FILE="/etc/systemd/system/nid-feature-extract.service"
TIMER_FILE="/etc/systemd/system/nid-feature-extract.timer"

echo "[+] Setting up automatic PCAP feature extraction on Ubuntu-Server..."

sudo apt update
sudo apt install -y python3 tcpdump

mkdir -p "$FEATURE_DIR"

echo "[+] Creating feature extraction script..."

cat > "$EXTRACT_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3

import csv
import os
import re
import subprocess
from pathlib import Path

BASE_DIR = Path("/home/ubuntu/ML-Network-Intrusion-detection/evidence")
PCAP_DIRS = [
    BASE_DIR / "pcaps",
    BASE_DIR / "pcaps" / "auto"
]
LABEL_FILE = BASE_DIR / "labels" / "master-labels.csv"
OUTPUT_FILE = BASE_DIR / "features" / "dataset_features.csv"

def load_labels():
    labels = {}
    if LABEL_FILE.exists():
        with open(LABEL_FILE, newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                labels[row["pcap_file"]] = {
                    "attack_class": row.get("attack_class", "unknown"),
                    "attack_type": row.get("attack_type", "unknown")
                }
    return labels

def run_tcpdump(pcap):
    try:
        result = subprocess.run(
            ["tcpdump", "-nn", "-tt", "-r", str(pcap)],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=20
        )
        return result.stdout.splitlines()
    except Exception:
        return []

def extract_features(pcap):
    lines = run_tcpdump(pcap)

    packet_count = 0
    icmp_count = 0
    arp_count = 0
    tcp_count = 0
    udp_count = 0
    tcp_syn_count = 0
    tcp_rst_count = 0
    total_bytes = 0
    first_time = None
    last_time = None
    src_ips = set()
    dst_ips = set()

    for line in lines:
        packet_count += 1

        parts = line.split()
        if parts:
            try:
                ts = float(parts[0])
                if first_time is None:
                    first_time = ts
                last_time = ts
            except Exception:
                pass

        if " ICMP " in line:
            icmp_count += 1

        if " ARP," in line:
            arp_count += 1

        if " UDP," in line:
            udp_count += 1

        if " Flags " in line:
            tcp_count += 1
            if "Flags [S]" in line:
                tcp_syn_count += 1
            if "Flags [R" in line:
                tcp_rst_count += 1

        length_match = re.search(r"length (\d+)", line)
        if length_match:
            total_bytes += int(length_match.group(1))

        ip_match = re.search(r"IP (\d+\.\d+\.\d+\.\d+)\.\d+ > (\d+\.\d+\.\d+\.\d+)\.\d+:", line)
        if ip_match:
            src_ips.add(ip_match.group(1))
            dst_ips.add(ip_match.group(2))
        else:
            ip_match = re.search(r"IP (\d+\.\d+\.\d+\.\d+) > (\d+\.\d+\.\d+\.\d+):", line)
            if ip_match:
                src_ips.add(ip_match.group(1))
                dst_ips.add(ip_match.group(2))

    duration = 0
    if first_time is not None and last_time is not None:
        duration = round(last_time - first_time, 6)

    return {
        "pcap_file": pcap.name,
        "pcap_path": str(pcap),
        "packet_count": packet_count,
        "icmp_count": icmp_count,
        "arp_count": arp_count,
        "tcp_count": tcp_count,
        "udp_count": udp_count,
        "tcp_syn_count": tcp_syn_count,
        "tcp_rst_count": tcp_rst_count,
        "total_bytes": total_bytes,
        "duration_seconds": duration,
        "unique_src_ips": len(src_ips),
        "unique_dst_ips": len(dst_ips)
    }

def infer_label(features, known_labels):
    name = features["pcap_file"]

    if name in known_labels:
        return known_labels[name]["attack_class"], known_labels[name]["attack_type"]

    if features["tcp_syn_count"] >= 20:
        return "reconnaissance", "possible_syn_scan"

    if features["icmp_count"] > 0 and features["tcp_syn_count"] == 0:
        return "normal", "icmp_ping_auto"

    return "unknown", "unlabeled"

def main():
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    labels = load_labels()
    rows = []

    for pcap_dir in PCAP_DIRS:
        if not pcap_dir.exists():
            continue

        for pcap in sorted(pcap_dir.glob("*.pcap")):
            if pcap.stat().st_size <= 100:
                continue

            features = extract_features(pcap)

            if features["packet_count"] == 0:
                continue

            attack_class, attack_type = infer_label(features, labels)
            features["attack_class"] = attack_class
            features["attack_type"] = attack_type

            rows.append(features)

    fieldnames = [
        "pcap_file",
        "pcap_path",
        "packet_count",
        "icmp_count",
        "arp_count",
        "tcp_count",
        "udp_count",
        "tcp_syn_count",
        "tcp_rst_count",
        "total_bytes",
        "duration_seconds",
        "unique_src_ips",
        "unique_dst_ips",
        "attack_class",
        "attack_type"
    ]

    with open(OUTPUT_FILE, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"[+] Extracted features from {len(rows)} PCAP files")
    print(f"[+] Dataset saved to: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
PYEOF

chmod +x "$EXTRACT_SCRIPT"

echo "[+] Creating systemd service..."

sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=NID PCAP Feature Extraction Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=ubuntu
ExecStart=/usr/bin/python3 $EXTRACT_SCRIPT
EOF

echo "[+] Creating systemd timer..."

sudo tee "$TIMER_FILE" > /dev/null << EOF
[Unit]
Description=Run NID PCAP Feature Extraction Every Minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Unit=nid-feature-extract.service

[Install]
WantedBy=timers.target
EOF

echo "[+] Reloading systemd..."
sudo systemctl daemon-reload

echo "[+] Enabling feature extraction timer..."
sudo systemctl enable --now nid-feature-extract.timer

echo "[+] Running feature extraction now..."
sudo systemctl start nid-feature-extract.service

echo
echo "[+] Feature extraction service status:"
sudo systemctl status nid-feature-extract.service --no-pager

echo
echo "[+] Dataset preview:"
cat "$FEATURE_DIR/dataset_features.csv"

echo
echo "[+] Done. PCAP features will now be extracted automatically every minute."
