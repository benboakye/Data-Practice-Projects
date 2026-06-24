#!/usr/bin/env python3

import json
from pathlib import Path

import joblib
import pandas as pd


BASE_DIR = Path(__file__).resolve().parents[2]

FEATURE_FILE = BASE_DIR / "evidence" / "features" / "dataset_features.csv"
MODEL_DIR = BASE_DIR / "evidence" / "ml"
ALERT_DIR = BASE_DIR / "evidence" / "alerts"

MODEL_FILE = MODEL_DIR / "nid_random_forest_model.joblib"
ENCODER_FILE = MODEL_DIR / "label_encoder.joblib"
FEATURE_COLUMNS_FILE = MODEL_DIR / "feature_columns.json"

OUTPUT_CSV = ALERT_DIR / "ids_predictions.csv"
OUTPUT_JSON = ALERT_DIR / "latest-alerts.json"


def load_feature_columns():
    with open(FEATURE_COLUMNS_FILE, "r") as f:
        return json.load(f)


def get_alert_level(predicted_class, confidence):
    if predicted_class == "normal":
        return "OK"

    if confidence >= 0.85:
        return "HIGH"

    if confidence >= 0.65:
        return "MEDIUM"

    return "LOW"


def main():
    ALERT_DIR.mkdir(parents=True, exist_ok=True)

    if not FEATURE_FILE.exists():
        raise FileNotFoundError(f"Feature file not found: {FEATURE_FILE}")

    if not MODEL_FILE.exists():
        raise FileNotFoundError(f"Model file not found: {MODEL_FILE}")

    if not ENCODER_FILE.exists():
        raise FileNotFoundError(f"Label encoder not found: {ENCODER_FILE}")

    if not FEATURE_COLUMNS_FILE.exists():
        raise FileNotFoundError(f"Feature columns file not found: {FEATURE_COLUMNS_FILE}")

    print("[+] Loading feature dataset...")
    df = pd.read_csv(FEATURE_FILE)

    print("[+] Loading ML model...")
    model = joblib.load(MODEL_FILE)
    label_encoder = joblib.load(ENCODER_FILE)
    feature_columns = load_feature_columns()

    missing_columns = [col for col in feature_columns if col not in df.columns]
    if missing_columns:
        raise ValueError(f"Missing required feature columns: {missing_columns}")

    X = df[feature_columns]

    print("[+] Running predictions...")
    predictions_encoded = model.predict(X)
    predictions = label_encoder.inverse_transform(predictions_encoded)

    probabilities = model.predict_proba(X)
    confidence_scores = probabilities.max(axis=1)

    df["predicted_class"] = predictions
    df["confidence"] = confidence_scores.round(4)

    df["alert_level"] = [
        get_alert_level(pred, conf)
        for pred, conf in zip(df["predicted_class"], df["confidence"])
    ]

    df["alert_message"] = df.apply(
        lambda row: (
            "Normal traffic detected"
            if row["predicted_class"] == "normal"
            else f"Suspicious traffic detected: {row['predicted_class']}"
        ),
        axis=1,
    )

    df.to_csv(OUTPUT_CSV, index=False)

    latest_alerts = df.tail(20).to_dict(orient="records")
    with open(OUTPUT_JSON, "w") as f:
        json.dump(latest_alerts, f, indent=4)

    print("[+] Prediction complete.")
    print(f"[+] CSV alerts saved to: {OUTPUT_CSV}")
    print(f"[+] JSON alerts saved to: {OUTPUT_JSON}")

    print("\nLatest predictions:")
    print(
        df[
            [
                "pcap_file",
                "attack_class",
                "predicted_class",
                "confidence",
                "alert_level",
                "alert_message",
            ]
        ].tail(10)
    )


if __name__ == "__main__":
    main()
