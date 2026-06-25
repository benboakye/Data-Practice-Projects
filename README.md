cd ~/ML-Network-Intrusion-detection

cat > add_ml_stats_api.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

REPO="$HOME/ML-Network-Intrusion-detection"
ALERTS_PY="$REPO/Defense System/manager/app/routes/alerts.py"

echo "[+] Backing up alerts.py..."
cp "$ALERTS_PY" "$ALERTS_PY.bak.stats.$(date +%Y%m%d-%H%M%S)"

echo "[+] Adding /api/alerts/ml/stats endpoint..."

python3 - <<'PY'
from pathlib import Path

repo = Path.home() / "ML-Network-Intrusion-detection"
alerts_py = repo / "Defense System" / "manager" / "app" / "routes" / "alerts.py"

text = alerts_py.read_text()

if "import csv" not in text:
    text = text.replace(
        "from datetime import datetime, timezone\n",
        "from datetime import datetime, timezone\nimport csv\n",
        1
    )

endpoint = '''

@router.get("/ml/stats")
def ml_alert_stats():
    """
    Return statistics from ML-generated IDS predictions.
    Reads evidence/alerts/ids_predictions.csv.
    """
    repo_root = Path(__file__).resolve().parents[4]
    csv_file = repo_root / "evidence" / "alerts" / "ids_predictions.csv"

    if not csv_file.exists():
        return {
            "total": 0,
            "normal": 0,
            "suspicious": 0,
            "by_predicted_class": {},
            "by_alert_level": {},
        }

    total = 0
    normal = 0
    suspicious = 0
    by_predicted_class = {}
    by_alert_level = {}

    with csv_file.open("r", newline="") as f:
        reader = csv.DictReader(f)

        for row in reader:
            total += 1

            predicted_class = row.get("predicted_class", "unknown")
            alert_level = row.get("alert_level", "UNKNOWN")

            by_predicted_class[predicted_class] = by_predicted_class.get(predicted_class, 0) + 1
            by_alert_level[alert_level] = by_alert_level.get(alert_level, 0) + 1

            if predicted_class == "normal":
                normal += 1
            else:
                suspicious += 1

    return {
        "total": total,
        "normal": normal,
        "suspicious": suspicious,
        "by_predicted_class": by_predicted_class,
        "by_alert_level": by_alert_level,
    }
'''

if '@router.get("/ml/stats")' not in text:
    text = text.rstrip() + endpoint + "\n"

alerts_py.write_text(text)
print("[+] ML stats endpoint added")
PY

echo "[+] Checking Python syntax..."
cd "$REPO/Defense System/manager"
python3 -m py_compile app/routes/alerts.py

echo "[+] Restarting AI Manager..."
sudo systemctl restart nid-manager
sleep 2

echo "[+] Testing ML stats endpoint..."
curl -s "http://127.0.0.1:8080/api/alerts/ml/stats" | python3 -m json.tool

echo "[+] Done."
BASH

chmod +x add_ml_stats_api.sh
./add_ml_stats_api.sh
