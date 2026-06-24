# Evidence Summary: AI-Based Network Intrusion Detection Lab

## Lab Topology

This lab was built to demonstrate a centralized AI-based network intrusion detection architecture. The lab contains an attacker machine, a monitored Linux host, a vulnerable target, and a central AI Manager.

| System         | Role                     |    IP Address | Status          |
| -------------- | ------------------------ | ------------: | --------------- |
| Kali Linux     | Attacker                 | 192.168.10.10 | Active          |
| Metasploitable | Vulnerable target        | 192.168.10.20 | Active          |
| Ubuntu-Host 1  | Monitored agent host     | 192.168.10.30 | Agent online    |
| Ubuntu-Server  | AI Manager and dashboard | 192.168.10.50 | Manager running |

## Manager and Agent Validation

The AI Manager was deployed on Ubuntu-Server at `192.168.10.50` and hosted the FastAPI backend and dashboard on port `8080`.

The monitored Ubuntu-Host 1 successfully registered with the AI Manager using the agent ID:

```text
agent-ubuntu-host1
```

The dashboard confirmed the agent as online with the following details:

```text
Hostname: cyberx
IP Address: 192.168.10.30
OS: linux
Status: online
```

## Captured Traffic Evidence

Two traffic captures were created and stored in the central evidence folder on the AI Manager.

### 1. Normal Traffic Capture

| Field          | Value                                               |
| -------------- | --------------------------------------------------- |
| PCAP file      | normal-ping-test.pcap                               |
| Source IP      | 192.168.10.10                                       |
| Destination IP | 192.168.10.30                                       |
| Traffic class  | normal                                              |
| Traffic type   | icmp_ping                                           |
| Description    | Kali sent normal ICMP ping traffic to Ubuntu-Host 1 |

This capture represents normal network traffic. The packet capture showed ICMP echo requests from Kali and ICMP echo replies from Ubuntu-Host 1.

### 2. Reconnaissance Attack Capture

| Field          | Value                                                 |
| -------------- | ----------------------------------------------------- |
| PCAP file      | nmap-scan-test.pcap                                   |
| Source IP      | 192.168.10.10                                         |
| Destination IP | 192.168.10.30                                         |
| Traffic class  | reconnaissance                                        |
| Traffic type   | nmap_syn_scan                                         |
| Description    | Kali performed an Nmap SYN scan against Ubuntu-Host 1 |

This capture represents reconnaissance activity. The packet capture showed SYN scan packets from Kali and reset replies from Ubuntu-Host 1 for closed ports.

## Evidence Folder Structure

```text
evidence/
├── pcaps/
│   ├── nmap-scan-test.pcap
│   └── normal-ping-test.pcap
└── labels/
    ├── nmap-scan-test-label.csv
    ├── normal-ping-test-label.csv
    └── master-labels.csv
```

## Result

The lab successfully demonstrated the following:

1. The AI Manager dashboard can run on Ubuntu-Server.
2. Ubuntu-Host 1 can register as an online monitored agent.
3. Kali can generate both normal and attack traffic.
4. Ubuntu-Host 1 can capture traffic from Kali.
5. PCAP evidence and label files can be stored centrally on the AI Manager.
6. The dataset now contains both normal and reconnaissance traffic samples for future feature extraction and machine learning processing.
