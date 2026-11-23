"""Minimal NetVision network KPI collector."""

from __future__ import annotations

import argparse
import json
import math
import os
import socket
import statistics
import time
from pathlib import Path
from typing import Iterable


def tcp_connect_latency_ms(host: str, port: int, timeout: float = 2.0) -> float:
    started = time.perf_counter()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return (time.perf_counter() - started) * 1000.0
    except OSError as error:
        raise RuntimeError(f"TCP probe failed for {host}:{port}: {error}") from error


def jitter_ms(latencies_ms: Iterable[float]) -> float:
    values = list(latencies_ms)
    if len(values) < 2:
        return 0.0
    return float(statistics.pstdev(values))


def probe_sample(
    node_id: str,
    host: str,
    port: int,
    probe_count: int = 10,
) -> dict:
    if not node_id.strip():
        raise ValueError("nodeId is required.")
    latencies = []
    tcp_failures = 0
    for _ in range(probe_count):
        try:
            latencies.append(tcp_connect_latency_ms(host, port))
        except RuntimeError:
            tcp_failures += 1
    if not latencies:
        raise RuntimeError(f"No successful TCP probes for {host}:{port}.")
    latency = statistics.mean(latencies)
    packet_loss = tcp_failures / probe_count
    retransmission_rate = 0.0
    return {
        "nodeId": node_id,
        "timestampUtc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "latency": round(latency, 3),
        "jitter": round(jitter_ms(latencies), 3),
        "packet_loss": round(packet_loss * 100.0, 3),
        "retransmission_rate": retransmission_rate,
        "signal_strength": None,
        "source": "collector",
    }


def require_write_key(dry_run: bool) -> str | None:
    if dry_run:
        return "DRY-RUN"
    emulator = os.environ.get("FIREBASE_EMULATOR", "")
    key = os.environ.get("NETVISION_COLLECTOR_KEY", "")
    if emulator == "1":
        return "EMULATOR"
    if not key:
        raise PermissionError(
            "NETVISION_COLLECTOR_KEY or FIREBASE_EMULATOR=1 is required."
        )
    if not os.path.isfile(key):
        raise PermissionError(
            "NETVISION_COLLECTOR_KEY must point to a service-account file."
        )
    return key


def write_sample(service_account: str, sample: dict) -> str:
    if os.environ.get("FIREBASE_EMULATOR") == "1":
        import firebase_admin
        from firebase_admin import credentials, firestore

        if not firebase_admin._apps:
            firebase_admin.initialize_app(
                credentials.ApplicationDefault()
                if os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
                else None
            )
    else:
        import firebase_admin
        from firebase_admin import credentials, firestore

        if not firebase_admin._apps:
            firebase_admin.initialize_app(credentials.Certificate(service_account))

    db = firestore.client()
    timestamp = time.strftime(
        "%Y%m%dT%H%M%S",
        time.gmtime(),
    )
    metric_id = f"collector-{timestamp}-{time.time_ns()}"
    node_ref = db.collection("networkNodes").document(sample["nodeId"])
    metric_fields = (
        ("latency", "latency", "ms"),
        ("jitter", "jitter", "ms"),
        ("packet_loss", "packetLoss", "%"),
        ("retransmission_rate", "retransmissionRate", "%"),
    )
    for sample_key, metric_type, unit in metric_fields:
        if sample_key not in sample:
            continue
        value = sample[sample_key]
        if value is None or not isinstance(value, (int, float)):
            continue
        ref = node_ref.collection("kpiMetrics").document(
            f"{metric_id}-{metric_type}"
        )
        ref.set({
            "metricTypeId": metric_type,
            "value": float(value),
            "unit": unit,
            "timestamp": firestore.SERVER_TIMESTAMP,
            "source": "collector",
            "quality": "good",
        })
    signal_strength = sample.get("signal_strength")
    if signal_strength is not None:
        node_ref.collection("kpiMetrics").document(
            f"{metric_id}-signalStrength"
        ).set({
            "metricTypeId": "signalStrength",
            "value": float(signal_strength),
            "unit": "dBm",
            "timestamp": firestore.SERVER_TIMESTAMP,
            "source": "collector",
            "quality": "good",
        })
    return metric_id


def load_yaml_config(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    targets = []
    current = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("- nodeId:"):
            if current:
                targets.append(current)
            current = {"nodeId": line.split(":", 1)[1].strip()}
        elif current and line.startswith("host:"):
            current["host"] = line.split(":", 1)[1].strip()
        elif current and line.startswith("port:"):
            current["port"] = int(line.split(":", 1)[1].strip())
        elif current and line.startswith("intervalSeconds:"):
            current["intervalSeconds"] = int(line.split(":", 1)[1].strip())
    if current:
        targets.append(current)
    if not targets:
        raise ValueError("Collector config has no targets.")
    return {"targets": targets}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="collector/config.example.yml")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--count", type=int, default=30)
    args = parser.parse_args(argv)
    credential = require_write_key(args.dry_run)
    config_path = Path(args.config)
    if not config_path.is_absolute():
        config_path = Path(__file__).resolve().parents[1] / config_path
    config = load_yaml_config(config_path)

    emitted = 0
    for target in config["targets"]:
        for _ in range(args.count):
            sample = probe_sample(
                target["nodeId"],
                target["host"],
                target["port"],
                probe_count=10,
            )
            print(json.dumps(sample, sort_keys=True))
            if not args.dry_run:
                write_sample(credential or "", sample)
            emitted += 1
    print(json.dumps({"dry_run": args.dry_run, "samples": emitted}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
