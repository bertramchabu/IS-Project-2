"""Deterministic synthetic enterprise replay engine."""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SEED = 166458


def load_scenarios() -> dict:
    return json.loads(
        (ROOT / "assets/simulation/scenarios.json").read_text(encoding="utf-8")
    )


def generate_samples(
    scenario: str,
    duration_seconds: int,
    seed: int = SEED,
) -> list[dict]:
    rng = random.Random(seed)
    start = datetime(2026, 1, 1, tzinfo=timezone.utc)
    rows = []
    injection = (
        scenario != "normal_business_hours"
        and scenario != "morning_pos_peak"
    )
    for second in range(duration_seconds):
        progress = second / max(duration_seconds - 1, 1)
        fault = injection and second >= duration_seconds // 3
        latency = 25.0 + 8.0 * math.sin(second / 30.0) + rng.uniform(-2, 2)
        jitter = 3.0 + rng.uniform(-0.5, 0.5)
        packet_loss = 0.05 + rng.uniform(0, 0.03)
        retransmission = 0.4 + rng.uniform(-0.1, 0.1)
        signal_strength = -60.0 + rng.uniform(-2, 2)
        if fault:
            latency += 120.0 * progress
            jitter += 18.0 * progress
            packet_loss += 8.0 * progress
            retransmission += 8.0 * progress
            signal_strength -= 25.0 * progress
        rows.append({
            "timestampUtc": (start + timedelta(seconds=second)).isoformat(),
            "nodeId": "SYNTHETIC-DEMO-NODE",
            "scenario": scenario,
            "latency": round(latency, 3),
            "jitter": round(jitter, 3),
            "packet_loss": round(packet_loss, 3),
            "retransmission_rate": round(retransmission, 3),
            "signal_strength": round(signal_strength, 3),
            "source": "simulation",
        })
    return rows


def write_replay(rows: list[dict]) -> Path:
    output = ROOT / "model/data/simulation/enterprise_replay.csv"
    output.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "timestampUtc",
        "nodeId",
        "scenario",
        "latency",
        "jitter",
        "packet_loss",
        "retransmission_rate",
        "signal_strength",
        "source",
    ]
    with output.open("w", encoding="utf-8", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario", default="normal_business_hours")
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument("--duration", type=int, default=300)
    parser.add_argument("--speed", type=int, default=1)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    catalogue = {item["name"]: item for item in load_scenarios()["scenarios"]}
    if args.scenario not in catalogue:
        raise SystemExit(f"Unknown scenario: {args.scenario}")
    if args.speed < 1:
        raise SystemExit("speed must be at least 1")

    rows = generate_samples(args.scenario, args.duration, args.seed)
    if args.dry_run:
        for row in rows[:10]:
            print(json.dumps(row, sort_keys=True))
        print(json.dumps({"dry_run": True, "scenario": args.scenario, "rows": len(rows)}))
        return 0

    output = write_replay(rows)
    print(json.dumps({"output": str(output), "rows": len(rows), "simulationOnly": True}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
