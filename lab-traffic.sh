#!/bin/bash

TARGET="192.168.10.30"

echo "[+] Controlled lab traffic generator"
echo "[+] Target: $TARGET"
echo "[+] No packages will be installed."
echo

echo "[1/5] Normal ping traffic..."
ping -c 20 "$TARGET"
sleep 70

echo "[2/5] Normal HTTP traffic..."
for i in {1..20}; do
    curl -s --max-time 3 "http://$TARGET" > /dev/null
    sleep 1
done
sleep 70

echo "[3/5] Light Nmap scan..."
nmap -Pn --top-ports 50 "$TARGET"
sleep 70

echo "[4/5] SYN scan..."
sudo nmap -sS -Pn --top-ports 100 "$TARGET"
sleep 70

echo "[5/5] Service/version scan..."
nmap -sV -Pn "$TARGET"
sleep 90

echo
echo "[+] Done. Traffic generation completed."
echo "[+] Now check Ubuntu-Server dataset_features.csv"
