cd ~/ML-Network-Intrusion-detection/evidence

cat > labels/master-labels.csv << 'EOF'
pcap_file,source_ip,destination_ip,attack_class,attack_type,description
nmap-scan-test.pcap,192.168.10.10,192.168.10.30,reconnaissance,nmap_syn_scan,Kali performed an Nmap SYN scan against Ubuntu-Host 1
normal-ping-test.pcap,192.168.10.10,192.168.10.30,normal,icmp_ping,Kali sent normal ICMP ping traffic to Ubuntu-Host 1
EOF
