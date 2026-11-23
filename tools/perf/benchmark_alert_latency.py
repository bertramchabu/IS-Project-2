"""Benchmark deployed predict_fault wall-clock latency.

This script intentionally requires an externally authenticated callable client.
It does not fabricate deployed measurements.
"""

from __future__ import annotations

import argparse
import json
import statistics
import time
from datetime import datetime, timezone
from pathlib import Path


def percentile(values: list[float], percent: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = round((len(ordered) - 1) * percent)
    return ordered[max(0, min(index, len(ordered) - 1))]


def benchmark(n: int, url: str | None) -> dict:
    if not url:
        raise SystemExit(
            "A deployed callable URL is required; no synthetic latency was generated."
        )
    # External HTTP/Firebase callable transport is intentionally not simulated.
    raise SystemExit(
        "Deployed callable benchmark requires Firebase client authentication "
        "and is not available in this local dry-run."
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=100)
    parser.add_argument("--url", default=None)
    args = parser.parse_args()
    benchmark(args.n, args.url)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
