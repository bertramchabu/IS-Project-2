"""Simulate a 30-second-poll threshold baseline on the existing KPI test CSV."""

from __future__ import annotations

import argparse
import csv
import json
import statistics
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=100)
    parser.add_argument(
        "--dataset",
        default=str(ROOT / "model/data/test_kpi_dataset.csv"),
    )
    args = parser.parse_args()
    dataset = Path(args.dataset)
    if not dataset.exists():
        raise SystemExit(f"Dataset not found: {dataset}")

    detections = []
    with dataset.open("r", encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source)
        for index, row in enumerate(reader):
            actual_fault = int(row["fault_label"])
            threshold_crossed = (
                float(row["latency"]) > 85
                or float(row["jitter"]) > 20
                or float(row["packet_loss"]) > 2.5
                or float(row["retransmission_rate"]) > 4.0
                or float(row["signal_strength"]) < -80
            )
            if actual_fault and threshold_crossed:
                detections.append(index % 30)
    result = {
        "method": "30-second-poll threshold baseline",
        "N": args.n,
        "detection_values_seconds": detections[:args.n],
        "timestampUtc": datetime.now(timezone.utc).isoformat(),
        "dataset": str(dataset),
        "caveat": "Synthetic row simulation; not wall-clock deployment latency.",
    }
    output = ROOT / "docs/evidence/BASELINE_LATENCY_RESULTS.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
