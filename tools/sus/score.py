"""Score SUS response CSV files."""

from __future__ import annotations

import argparse
import csv
import json
import statistics
from datetime import datetime, timezone
from pathlib import Path


def score_row(row: dict[str, str]) -> float:
    odd = sum(int(row[str(index)]) - 1 for index in range(1, 11, 2))
    even = sum(5 - int(row[str(index)]) for index in range(2, 11, 2))
    return (odd + even) * 2.5


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("responses_csv")
    args = parser.parse_args()
    scores = []
    with Path(args.responses_csv).open("r", encoding="utf-8", newline="") as source:
        reader = csv.DictReader(source)
        for row in reader:
            scores.append({
                "participantId": row["participantId"],
                "sus": score_row(row),
            })
    if not scores:
        raise SystemExit("No SUS responses found.")
    values = [item["sus"] for item in scores]
    result = {
        "n": len(scores),
        "mean": statistics.fmean(values),
        "stddev": statistics.pstdev(values),
        "participants": scores,
        "timestampUtc": datetime.now(timezone.utc).isoformat(),
    }
    output = Path(__file__).resolve().parents[2] / "docs/evidence/SUS_RESULTS.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
