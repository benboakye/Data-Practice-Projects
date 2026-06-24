#!/bin/bash

TARGET="${1:-192.168.10.30}"

echo "[+] Fast training traffic collection"
echo "[+] Target: $TARGET"
echo "[+] No packages will be installed."
echo "[+] Ubuntu-Host capture rotation should already be 20 seconds."
echo

read -p "Press Enter to start..."

for i in {1..10}; do
    echo
    echo "========== ROUND $i / 10 =========="

    echo "[+] Normal ICMP traffic sample..."
    ping -c 10 "$TARGET"
    sleep 25

    echo "[+] Normal HTTP traffic sample..."
    for j in {1..10}; do
        curl -s --max-time 3 "http://$TARGET" > /dev/null
        sleep 1
    done
    sleep 25

    echo "[+] Reconnaissance sample: light TCP scan..."
    nmap -Pn --top-ports 50 "$TARGET"
    sleep 25

    echo "[+] Reconnaissance sample: SYN scan..."
    sudo nmap -sS -Pn --top-ports 100 "$TARGET"
    sleep 25
done

echo
echo "[+] Done. Wait 2 minutes, then check Ubuntu-Server dataset_features.csv."
