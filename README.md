cd ~/ML-Network-Intrusion-detection

cat > connect_ml_alerts_api.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

REPO="$HOME/ML-Network-Intrusion-detection"
DEF="$REPO/Defense System"
ALERTS_PY="$DEF/manager/app/routes/alerts.py"
ML_JSON="$REPO/evidence/alerts/latest-alerts.json"

echo "[+] Checking files..."

if [ ! -f "$ALERTS_PY" ]; then
  echo "[!] alerts.py not found: $ALERTS_PY"
  exit 1
fi

if [ ! -f "$ML_JSON" ]; then
  echo "[!] ML JSON alert file not found: $ML_JSON"
  exit 1
fi

echo "[+] Backing up alerts.py..."
cp "$ALERTS_PY" "$ALERTS_PY.bak.$(date +%Y%m%d-%H%M%S)"

echo "[+] Adding ML alert API endpoint..."

python3 - <<'PY'
from pathlib import Path

repo = Path.home() / "ML-Network-Intrusion-detection"
alerts_py = repo / "Defense System" / "manager" / "app" / "routes" / "alerts.py"

text = alerts_py.read_text()

if "import json" not in text:
    text = text.replace(
        "from datetime import datetime, timezone\n",
        "from datetime import datetime, timezone\nimport json\nfrom pathlib import Path\n",
        1
    )

endpoint = '''

@router.get("/ml/latest")
def latest_ml_alerts(limit: int = Query(default=20, le=200)):
    """
    Return latest machine-learning IDS alerts generated from latest-alerts.json.
    This endpoint connects the deployed ML prediction output to the manager API.
    """
    repo_root = Path(__file__).resolve().parents[4]
    alerts_file = repo_root / "evidence" / "alerts" / "latest-alerts.json"

    if not alerts_file.exists():
        return []

    try:
        data = json.loads(alerts_file.read_text())
    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="ML alerts JSON file is invalid")

    if not isinstance(data, list):
        raise HTTPException(status_code=500, detail="ML alerts JSON must contain a list")

    return data[-limit:]
'''

if '@router.get("/ml/latest")' not in text:
    text = text.rstrip() + endpoint + "\n"

alerts_py.write_text(text)
print("[+] alerts.py updated successfully")
PY

echo "[+] Checking Python syntax..."
cd "$DEF/manager"
python3 -m py_compile app/routes/alerts.py

echo "[+] Restarting AI Manager..."
sudo systemctl restart nid-manager
sleep 2

echo "[+] Service status:"
sudo systemctl is-active nid-manager

echo "[+] Testing health endpoint:"
curl -s http://127.0.0.1:8080/api/health
echo

echo "[+] Testing ML alerts endpoint:"
curl -s "http://127.0.0.1:8080/api/alerts/ml/latest?limit=3" | python3 -m json.tool

echo "[+] Done."
BASH

chmod +x connect_ml_alerts_api.sh
./connect_ml_alerts_api.sh
