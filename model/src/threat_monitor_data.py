"""Build reproducible, explicitly synthetic 60-second threat windows from CIC-IDS2017.

The CIC files contain flow rows but no timestamps, site identifiers, or service
health outcomes. This module therefore samples flow profiles for synthetic
windows; all grouping, timestamps, node identifiers, service outcomes, and
operational fault labels it creates are synthetic.
"""

from __future__ import annotations

import csv
import hashlib
import json
import math
import random
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable


DATASET_VERSION = "threat-synthetic-v1"
SCHEMA_VERSION = 1
WINDOW_SECONDS = 60
LABELS = (
    "BENIGN",
    "AVAILABILITY_ANOMALY",
    "OPERATIONAL_FAULT",
    "UNKNOWN",
)


def map_cic_label(raw_label: str) -> str:
    """Map CIC labels conservatively; non-availability attacks remain UNKNOWN."""
    normalized = raw_label.strip().casefold().replace(" ", "").replace("-", "")
    if normalized == "benign":
        return "BENIGN"
    if normalized.startswith("ddos") or normalized.startswith("dos"):
        return "AVAILABILITY_ANOMALY"
    return "UNKNOWN"


@dataclass(frozen=True)
class CicProfiles:
    samples: dict[str, dict[str, tuple[dict[str, float], ...]]]
    row_counts: dict[str, dict[str, int]]
    source_hashes: dict[str, str]
    source_files: tuple[str, ...]


def _finite_number(row: dict[str, str], key: str) -> float:
    try:
        value = float(row.get(key, ""))
    except (TypeError, ValueError):
        return 0.0
    return value if math.isfinite(value) and value >= 0 else 0.0


def _profile_row(row: dict[str, str]) -> dict[str, float]:
    forward = _finite_number(row, "Total Fwd Packets")
    backward = _finite_number(row, "Total Backward Packets")
    protocol = _finite_number(row, "Protocol")
    return {
        "packets_per_sec": min(_finite_number(row, "Flow Packets/s"), 1e9),
        "bytes_per_sec": min(_finite_number(row, "Flow Bytes/s"), 1e12),
        "duration_seconds": min(
            _finite_number(row, "Flow Duration") / 1_000_000, WINDOW_SECONDS
        ),
        "inbound_outbound_ratio": min(
            forward / backward if backward > 0 else float(forward > 0), 1e6
        ),
        "protocol": protocol,
        "destination_port": min(
            _finite_number(row, "Destination Port"), 65535
        ),
        **{
            f"tcp_flag_{name}": _finite_number(row, f"{name} Flag Count")
            for name in ("SYN", "ACK", "FIN", "RST", "PSH", "URG", "CWE", "ECE")
        },
    }


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_cic_profiles(
    data_directory: Path,
    *,
    max_samples_per_class: int = 2_000,
    seed: int = 42,
) -> CicProfiles:
    """Stream CIC CSVs; retain only bounded, non-identifying numeric flow profiles."""
    if max_samples_per_class < 1:
        raise ValueError("max_samples_per_class must be positive.")
    files = tuple(sorted(data_directory.glob("*.csv")))
    if not files:
        raise FileNotFoundError(f"No CIC CSV files found in {data_directory}.")

    rng = random.Random(seed)
    split_names = ("train", "validation", "test")
    labels = tuple(label for label in LABELS if label != "OPERATIONAL_FAULT")
    counts = {split: Counter() for split in split_names}
    reservoirs = {
        split: {label: [] for label in labels} for split in split_names
    }
    hashes: dict[str, str] = {}

    for file_index, path in enumerate(files):
        hashes[path.name] = _sha256_file(path)
        with path.open("r", encoding="utf-8-sig", errors="replace", newline="") as source:
            reader = csv.DictReader(source)
            if not reader.fieldnames or "Label" not in {
                name.strip() for name in reader.fieldnames
            }:
                raise ValueError(f"{path.name} does not have a Label column.")
            for row_index, raw_row in enumerate(reader):
                row = {key.strip(): value for key, value in raw_row.items() if key}
                label = map_cic_label(row.get("Label", ""))
                split_bucket = (row_index * 31 + file_index * 17) % 100
                split = (
                    "train"
                    if split_bucket < 70
                    else "validation"
                    if split_bucket < 85
                    else "test"
                )
                counts[split][label] += 1
                reservoir = reservoirs[split][label]
                sample = _profile_row(row)
                if len(reservoir) < max_samples_per_class:
                    reservoir.append(sample)
                else:
                    replacement = rng.randrange(counts[split][label])
                    if replacement < max_samples_per_class:
                        reservoir[replacement] = sample

    for split in split_names:
        missing_labels = [label for label in labels if not reservoirs[split][label]]
        if missing_labels:
            raise ValueError(
                f"CIC {split} partition lacks profiles for: "
                + ", ".join(missing_labels)
            )

    return CicProfiles(
        samples={
            split: {
                label: tuple(value) for label, value in class_samples.items()
            }
            for split, class_samples in reservoirs.items()
        },
        row_counts={
            split: dict(split_counts) for split, split_counts in counts.items()
        },
        source_hashes=hashes,
        source_files=tuple(path.name for path in files),
    )


def _aggregate_profile_window(
    samples: tuple[dict[str, float], ...], rng: random.Random
) -> dict[str, object]:
    selected = [rng.choice(samples) for _ in range(32)]
    protocol_counts = Counter(
        {
            "tcp": sum(int(row["protocol"]) == 6 for row in selected),
            "udp": sum(int(row["protocol"]) == 17 for row in selected),
            "icmp": sum(int(row["protocol"]) == 1 for row in selected),
        }
    )
    protocol_counts["other"] = 32 - sum(protocol_counts.values())
    port_counts = Counter(
        str(int(row["destination_port"]))
        for row in selected
        if row["destination_port"] > 0
    )
    flag_counts = {
        name: int(sum(row[f"tcp_flag_{name}"] for row in selected))
        for name in ("SYN", "ACK", "FIN", "RST", "PSH", "URG", "CWE", "ECE")
    }
    return {
        **{
            name: sum(row[name] for row in selected) / len(selected)
            for name in (
                "packets_per_sec",
                "bytes_per_sec",
                "duration_seconds",
                "inbound_outbound_ratio",
            )
        },
        "protocol_proportions": {
            name: count / len(selected) for name, count in protocol_counts.items()
        },
        "destination_port_counts": dict(port_counts.most_common(5)),
        "tcp_flag_counts": flag_counts,
    }


def _entropy(rng: random.Random, label: str) -> float:
    bounds = {
        "BENIGN": (2.0, 6.0),
        "AVAILABILITY_ANOMALY": (0.05, 2.0),
        "OPERATIONAL_FAULT": (2.0, 6.0),
        "UNKNOWN": (0.1, 5.0),
    }
    return rng.uniform(*bounds[label])


def _feature_values(
    label: str, profile: dict[str, object], rng: random.Random
) -> dict[str, object]:
    rate_scale = {
        "BENIGN": 1.0,
        "AVAILABILITY_ANOMALY": 8.0,
        "OPERATIONAL_FAULT": 1.2,
        "UNKNOWN": 2.0,
    }[label]
    flow_starts_per_sec = rng.lognormvariate(math.log(rate_scale), 0.45)
    total_connections = max(1, round(flow_starts_per_sec * WINDOW_SECONDS))
    failed_probability = {
        "BENIGN": 0.02,
        "AVAILABILITY_ANOMALY": 0.45,
        "OPERATIONAL_FAULT": 0.08,
        "UNKNOWN": 0.18,
    }[label]
    failed = sum(rng.random() < failed_probability for _ in range(total_connections))
    incomplete = sum(
        rng.random() < failed_probability / 2 for _ in range(total_connections)
    )

    error_rate = {
        "BENIGN": rng.uniform(0, 0.03),
        "AVAILABILITY_ANOMALY": rng.uniform(0.05, 0.4),
        "OPERATIONAL_FAULT": rng.uniform(0.25, 0.8),
        "UNKNOWN": rng.uniform(0, 0.5),
    }[label]
    timeout_rate = {
        "BENIGN": rng.uniform(0, 0.02),
        "AVAILABILITY_ANOMALY": rng.uniform(0.05, 0.35),
        "OPERATIONAL_FAULT": rng.uniform(0.1, 0.5),
        "UNKNOWN": rng.uniform(0, 0.4),
    }[label]
    latency_bounds = {
        "BENIGN": (5, 120),
        "AVAILABILITY_ANOMALY": (80, 1_200),
        "OPERATIONAL_FAULT": (200, 2_000),
        "UNKNOWN": (5, 1_500),
    }
    source_entropy = _entropy(rng, label)
    destination_entropy = _entropy(rng, label)
    return {
        "packets_per_sec": profile["packets_per_sec"],
        "bytes_per_sec": profile["bytes_per_sec"],
        "flow_starts_per_sec": flow_starts_per_sec,
        "inbound_outbound_ratio": profile["inbound_outbound_ratio"],
        "concurrent_connections": max(1, round(total_connections * rng.uniform(0.1, 0.8))),
        "total_connections": total_connections,
        "failed_connections": failed,
        "incomplete_connections": incomplete,
        "average_connection_duration_seconds": profile["duration_seconds"],
        "protocol_proportions": profile["protocol_proportions"],
        "destination_port_counts": profile["destination_port_counts"],
        "tcp_flag_counts": profile["tcp_flag_counts"],
        "source_address_entropy": source_entropy,
        "destination_address_entropy": destination_entropy,
        "top_destination_share": min(1.0, 1 / (2 ** destination_entropy)),
        "success_rate": max(0.0, 1.0 - error_rate - timeout_rate),
        "error_rate": error_rate,
        "timeout_rate": timeout_rate,
        "p95_latency_ms": rng.uniform(*latency_bounds[label]),
        "queue_saturation": min(
            1.0,
            rng.uniform(0.05, 0.55)
            if label == "BENIGN"
            else rng.uniform(0.45, 1.0),
        ),
    }


def _labels_for_site(
    site_index: int, count: int, rng: random.Random
) -> tuple[list[str], list[str | None]]:
    labels = ["BENIGN"] * count
    event_ids: list[str | None] = [None] * count
    categories = ("AVAILABILITY_ANOMALY", "OPERATIONAL_FAULT", "UNKNOWN")
    position = 30 + site_index % 19
    event_number = 0
    while position + 5 < count:
        label = categories[(event_number + site_index) % len(categories)]
        duration = min(rng.randint(5, 24), count - position)
        event_id = f"synthetic-site-{site_index:03d}-event-{event_number:04d}"
        for index in range(position, position + duration):
            labels[index] = label
            event_ids[index] = event_id
        position += duration + rng.randint(25, 80)
        event_number += 1
    return labels, event_ids


def _site_split(site_index: int, site_count: int) -> str:
    train_end = int(site_count * 0.70)
    validation_end = int(site_count * 0.85)
    if site_index < train_end:
        return "train"
    if site_index < validation_end:
        return "validation"
    return "test"


def generate_synthetic_windows(
    profiles: CicProfiles,
    *,
    site_count: int = 40,
    windows_per_site: int = 1_000,
    gap_windows: int = 10,
    seed: int = 42,
) -> Iterable[dict[str, object]]:
    """Yield a deterministic synthetic dataset with disjoint sites and time blocks."""
    if site_count < 20 or windows_per_site < 100:
        raise ValueError("Use at least 20 sites and 100 windows per site.")
    if gap_windows < 10:
        raise ValueError("Split gap must be at least 10 windows.")
    rng = random.Random(seed)
    base_time = datetime(2025, 1, 1, tzinfo=timezone.utc)
    train_end = int(windows_per_site * 0.70)
    validation_end = int(windows_per_site * 0.85)

    for site_index in range(site_count):
        split = _site_split(site_index, site_count)
        if split == "train":
            start_index, end_index = 0, train_end
        elif split == "validation":
            start_index = train_end + gap_windows
            end_index = validation_end
        else:
            start_index = validation_end + gap_windows
            end_index = windows_per_site

        labels, event_ids = _labels_for_site(site_index, windows_per_site, rng)
        for index in range(start_index, end_index):
            label = labels[index]
            source_label = label
            profile_class = "BENIGN" if label == "OPERATIONAL_FAULT" else label
            profile = _aggregate_profile_window(
                profiles.samples[split][profile_class], rng
            )
            feature_values = _feature_values(label, profile, rng)
            for key in (
                "protocol_proportions",
                "destination_port_counts",
                "tcp_flag_counts",
            ):
                feature_values[key] = json.dumps(feature_values[key], sort_keys=True)
            window_start = base_time + timedelta(seconds=index * WINDOW_SECONDS)
            quality_flags = [
                "synthetic_window",
                "synthetic_time",
                "synthetic_node",
                "synthetic_service_outcomes",
                "cic_flow_profile",
            ]
            yield {
                "schema_version": SCHEMA_VERSION,
                "dataset_version": DATASET_VERSION,
                "source_dataset": "CIC-IDS2017",
                "source_record_type": "synthetic_60_second_window",
                "source_label": source_label,
                "node_id": f"synthetic-site-{site_index:03d}",
                "service_id": f"synthetic-service-{site_index % 5:02d}",
                "split": split,
                "event_id": event_ids[index] or "",
                "window_start_utc": window_start.isoformat(),
                "window_end_utc": (window_start + timedelta(seconds=WINDOW_SECONDS)).isoformat(),
                "label": label,
                **feature_values,
                "capacity_profile": "synthetic-standard",
                "maintenance_window": False,
                "recent_deployment": False,
                "data_quality_flags": json.dumps(quality_flags),
            }


def write_dataset(
    data_directory: Path,
    output_path: Path,
    *,
    site_count: int = 40,
    windows_per_site: int = 1_000,
    gap_windows: int = 10,
    seed: int = 42,
) -> dict[str, object]:
    """Write versioned CSV and provenance manifest without storing raw flow IDs."""
    profiles = load_cic_profiles(data_directory, seed=seed)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    row_count = 0
    split_counts: Counter[str] = Counter()
    label_counts: Counter[str] = Counter()
    with output_path.open("w", encoding="utf-8", newline="") as target:
        writer: csv.DictWriter[str] | None = None
        for row in generate_synthetic_windows(
            profiles,
            site_count=site_count,
            windows_per_site=windows_per_site,
            gap_windows=gap_windows,
            seed=seed,
        ):
            if writer is None:
                writer = csv.DictWriter(target, fieldnames=list(row))
                writer.writeheader()
            writer.writerow(row)
            row_count += 1
            split_counts[str(row["split"])] += 1
            label_counts[str(row["label"])] += 1

    if writer is None:
        raise ValueError("No rows were generated.")
    manifest = {
        "dataset_version": DATASET_VERSION,
        "schema_version": SCHEMA_VERSION,
        "seed": seed,
        "window_seconds": WINDOW_SECONDS,
        "site_count": site_count,
        "windows_per_site": windows_per_site,
        "split_gap_windows": gap_windows,
        "row_count": row_count,
        "split_counts": dict(split_counts),
        "label_counts": dict(label_counts),
        "source_files": list(profiles.source_files),
        "source_sha256": profiles.source_hashes,
        "cic_class_row_counts_by_source_split": profiles.row_counts,
        "source_row_partition": (
            "Each CIC row is assigned to exactly one source partition by "
            "(row_index * 31 + sorted_file_index * 17) mod 100: "
            "0-69 train, 70-84 validation, 85-99 test."
        ),
        "limitations": [
            "CIC-IDS2017 has no timestamps, node/site identifiers, or service outcomes.",
            "All generated timestamps, sites, service outcomes, context, and operational faults are synthetic.",
            "This dataset is for pipeline testing only and cannot establish production detection efficacy.",
        ],
    }
    manifest_path = output_path.with_suffix(output_path.suffix + ".manifest.json")
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "data" / "threat",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1]
        / "data"
        / "threat"
        / "generated"
        / f"{DATASET_VERSION}.csv",
    )
    parser.add_argument("--sites", type=int, default=40)
    parser.add_argument("--windows-per-site", type=int, default=1_000)
    parser.add_argument("--gap-windows", type=int, default=10)
    parser.add_argument("--seed", type=int, default=42)
    arguments = parser.parse_args()
    result = write_dataset(
        arguments.data_dir,
        arguments.output,
        site_count=arguments.sites,
        windows_per_site=arguments.windows_per_site,
        gap_windows=arguments.gap_windows,
        seed=arguments.seed,
    )
    print(json.dumps(result, indent=2))
