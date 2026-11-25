"""Compare tree and temporal threat models on the synthetic CIC-profiled dataset.

All reported scores from this harness are simulation-only. They are not
evidence of production attack detection or forecast performance.
"""

from __future__ import annotations

import csv
import hashlib
import json
import math
import subprocess
import time
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
from sklearn.ensemble import HistGradientBoostingClassifier, IsolationForest
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    auc,
    confusion_matrix,
    f1_score,
    precision_recall_curve,
    precision_recall_fscore_support,
)
from sklearn.neural_network import MLPClassifier
from sklearn.preprocessing import StandardScaler

from src.threat_monitor_data import DATASET_VERSION, LABELS


BASE_FEATURES = (
    "packets_per_sec",
    "bytes_per_sec",
    "flow_starts_per_sec",
    "inbound_outbound_ratio",
    "concurrent_connections",
    "total_connections",
    "failed_connections",
    "incomplete_connections",
    "average_connection_duration_seconds",
)
PROTOCOL_FEATURES = (
    "protocol_tcp",
    "protocol_udp",
    "protocol_icmp",
    "protocol_other",
)
PORT_FEATURES = ("top_destination_port_count", "top_destination_port_share")
TCP_FLAG_FEATURES = (
    "tcp_syn_flag_count",
    "tcp_ack_flag_count",
    "tcp_rst_flag_count",
    "tcp_fin_flag_count",
)
OUTCOME_FEATURES = (
    "source_address_entropy",
    "destination_address_entropy",
    "top_destination_share",
    "success_rate",
    "error_rate",
    "timeout_rate",
    "p95_latency_ms",
    "queue_saturation",
)
FEATURES = (
    BASE_FEATURES
    + PROTOCOL_FEATURES
    + PORT_FEATURES
    + TCP_FLAG_FEATURES
    + OUTCOME_FEATURES
)
LABEL_TO_INDEX = {label: index for index, label in enumerate(LABELS)}
SEQUENCE_LENGTH = 10
FORECAST_HORIZON_WINDOWS = 10
SEED = 42


def _read_split(path: Path) -> dict[str, list[dict[str, object]]]:
    splits: dict[str, list[dict[str, object]]] = defaultdict(list)
    with path.open("r", encoding="utf-8", newline="") as source:
        for row in csv.DictReader(source):
            protocol = json.loads(row["protocol_proportions"])
            features = [float(row[name]) for name in BASE_FEATURES]
            features.extend(
                float(protocol[name]) for name in ("tcp", "udp", "icmp", "other")
            )
            port_counts = json.loads(row["destination_port_counts"])
            port_total = sum(port_counts.values())
            top_port_count = max(port_counts.values(), default=0)
            features.extend(
                (
                    float(top_port_count),
                    float(top_port_count / port_total) if port_total else 0.0,
                )
            )
            tcp_flags = json.loads(row["tcp_flag_counts"])
            features.extend(
                float(tcp_flags.get(name, 0))
                for name in ("SYN", "ACK", "RST", "FIN")
            )
            features.extend(float(row[name]) for name in OUTCOME_FEATURES)
            if not all(np.isfinite(value) for value in features):
                raise ValueError("Dataset contains non-finite model features.")
            row["_features"] = features
            row["_label_index"] = LABEL_TO_INDEX[row["label"]]
            row["_time"] = datetime.fromisoformat(row["window_start_utc"])
            splits[row["split"]].append(row)
    return splits


def _build_sequences(
    rows: list[dict[str, object]],
) -> dict[str, object]:
    by_node: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        by_node[str(row["node_id"])].append(row)

    sequences: list[np.ndarray] = []
    labels: list[int] = []
    future_availability: list[int] = []
    metadata: list[dict[str, object]] = []
    for node_id, node_rows in sorted(by_node.items()):
        node_rows.sort(key=lambda item: item["_time"])
        features = [np.asarray(row["_features"], dtype=np.float64) for row in node_rows]
        current_labels = [int(row["_label_index"]) for row in node_rows]
        final_index = len(node_rows) - FORECAST_HORIZON_WINDOWS
        for index in range(SEQUENCE_LENGTH - 1, final_index):
            future_labels = current_labels[
                index + 1 : index + FORECAST_HORIZON_WINDOWS + 1
            ]
            sequences.append(np.stack(features[index - SEQUENCE_LENGTH + 1 : index + 1]))
            labels.append(current_labels[index])
            future_availability.append(
                int(LABEL_TO_INDEX["AVAILABILITY_ANOMALY"] in future_labels)
            )
            metadata.append(
                {
                    "node_id": node_id,
                    "timestamp": node_rows[index]["window_start_utc"],
                    "event_id": node_rows[index]["event_id"],
                    "true_label": current_labels[index],
                    "node_index": index,
                }
            )

    if not sequences:
        raise ValueError("A split has too few sequential windows.")
    return {
        "sequences": np.stack(sequences),
        "labels": np.asarray(labels, dtype=np.int64),
        "future_availability": np.asarray(future_availability, dtype=np.int64),
        "metadata": metadata,
    }


def _aligned_probabilities(model, values: np.ndarray) -> np.ndarray:
    raw = model.predict_proba(values)
    aligned = np.zeros((len(values), len(LABELS)), dtype=np.float64)
    for index, label in enumerate(model.classes_):
        aligned[:, int(label)] = raw[:, index]
    return aligned


def _fit_probability_calibrator(
    probabilities: np.ndarray, labels: np.ndarray, seed: int = SEED
) -> LogisticRegression:
    calibrator = LogisticRegression(max_iter=500, random_state=seed)
    calibrator.fit(np.log(np.clip(probabilities, 1e-7, 1.0)), labels)
    return calibrator


def _apply_calibrator(
    calibrator: LogisticRegression, probabilities: np.ndarray
) -> np.ndarray:
    calibrated = calibrator.predict_proba(
        np.log(np.clip(probabilities, 1e-7, 1.0))
    )
    aligned = np.zeros((len(probabilities), len(LABELS)), dtype=np.float64)
    for index, label in enumerate(calibrator.classes_):
        aligned[:, int(label)] = calibrated[:, index]
    return aligned


def _abstain_threshold(
    probabilities: np.ndarray, labels: np.ndarray
) -> tuple[float, float]:
    best_threshold = 0.5
    best_score = -1.0
    for threshold in (0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75):
        predictions = probabilities.argmax(axis=1)
        predictions[probabilities.max(axis=1) < threshold] = LABEL_TO_INDEX["UNKNOWN"]
        score = f1_score(labels, predictions, labels=range(len(LABELS)), average="macro")
        if score > best_score:
            best_threshold, best_score = threshold, float(score)
    return best_threshold, best_score


def _prediction_labels(
    probabilities: np.ndarray,
    threshold: float,
    ood: np.ndarray | None = None,
) -> np.ndarray:
    predictions = probabilities.argmax(axis=1)
    predictions[probabilities.max(axis=1) < threshold] = LABEL_TO_INDEX["UNKNOWN"]
    if ood is not None:
        predictions[ood] = LABEL_TO_INDEX["UNKNOWN"]
    return predictions


def _expected_calibration_error(
    probabilities: np.ndarray, labels: np.ndarray, bins: int = 10
) -> float:
    confidence = probabilities.max(axis=1)
    correct = probabilities.argmax(axis=1) == labels
    error = 0.0
    for lower in np.linspace(0, 1, bins, endpoint=False):
        upper = lower + 1 / bins
        mask = (confidence >= lower) & (confidence < upper)
        if np.any(mask):
            error += float(mask.mean()) * abs(
                float(confidence[mask].mean()) - float(correct[mask].mean())
            )
    return error


def _classification_metrics(
    truth: np.ndarray,
    predictions: np.ndarray,
    probabilities: np.ndarray,
    *,
    scores_are_probabilities: bool = True,
) -> dict[str, object]:
    precision, recall, f1, support = precision_recall_fscore_support(
        truth, predictions, labels=range(len(LABELS)), zero_division=0
    )
    per_class: dict[str, object] = {}
    pr_auc: dict[str, float | None] = {}
    for index, label in enumerate(LABELS):
        binary_truth = (truth == index).astype(int)
        if not scores_are_probabilities or binary_truth.min() == binary_truth.max():
            pr_auc[label] = None
        else:
            curve_precision, curve_recall, _ = precision_recall_curve(
                binary_truth, probabilities[:, index]
            )
            pr_auc[label] = float(auc(curve_recall, curve_precision))
        per_class[label] = {
            "precision": float(precision[index]),
            "recall": float(recall[index]),
            "f1": float(f1[index]),
            "support": int(support[index]),
        }
    return {
        "per_class": per_class,
        "macro_f1": float(np.mean(f1)),
        "confusion_matrix": confusion_matrix(
            truth, predictions, labels=range(len(LABELS))
        ).tolist(),
        "pr_auc": pr_auc,
        "brier_score_by_class": (
            {
                label: float(
                    np.mean(
                        (probabilities[:, index] - (truth == index).astype(float))
                        ** 2
                    )
                )
                for index, label in enumerate(LABELS)
            }
            if scores_are_probabilities
            else None
        ),
        "expected_calibration_error": (
            _expected_calibration_error(probabilities, truth)
            if scores_are_probabilities
            else None
        ),
        "scores_are_probabilities": scores_are_probabilities,
    }


def _rule_predictions(
    training: dict[str, object], testing: dict[str, object]
) -> tuple[np.ndarray, np.ndarray, dict[str, float]]:
    train_current = training["sequences"][:, -1, :]
    train_labels = training["labels"]
    benign = train_current[train_labels == LABEL_TO_INDEX["BENIGN"]]
    if len(benign) < 10:
        raise ValueError("Training split has too few BENIGN windows for rule baselines.")
    flow_threshold = float(np.quantile(benign[:, FEATURES.index("flow_starts_per_sec")], 0.995))
    entropy_threshold = float(
        np.quantile(benign[:, FEATURES.index("source_address_entropy")], 0.05)
    )

    values = testing["sequences"][:, -1, :]
    predictions = np.full(len(values), LABEL_TO_INDEX["BENIGN"], dtype=np.int64)
    operational = (
        (values[:, FEATURES.index("error_rate")] > 0.25)
        | (values[:, FEATURES.index("queue_saturation")] > 0.95)
    )
    availability = (
        (values[:, FEATURES.index("flow_starts_per_sec")] > flow_threshold)
        | (
            (values[:, FEATURES.index("source_address_entropy")] < entropy_threshold)
            & (values[:, FEATURES.index("top_destination_share")] > 0.7)
        )
        | (
            values[:, FEATURES.index("failed_connections")]
            / np.maximum(values[:, FEATURES.index("total_connections")], 1)
            > 0.5
        )
    )
    predictions[availability] = LABEL_TO_INDEX["AVAILABILITY_ANOMALY"]
    predictions[operational] = LABEL_TO_INDEX["OPERATIONAL_FAULT"]
    probabilities = np.eye(len(LABELS), dtype=np.float64)[predictions]
    return predictions, probabilities, {
        "flow_starts_per_sec_p995_benign": flow_threshold,
        "source_address_entropy_p05_benign": entropy_threshold,
        "failed_connection_ratio": 0.5,
        "operational_error_rate": 0.25,
        "operational_queue_saturation": 0.95,
    }


def _event_metrics(
    metadata: list[dict[str, object]],
    truth: np.ndarray,
    predictions: np.ndarray,
    risk_probabilities: np.ndarray,
    risk_threshold: float,
) -> dict[str, object]:
    grouped: dict[str, list[int]] = defaultdict(list)
    by_node: dict[str, list[int]] = defaultdict(list)
    for index, row in enumerate(metadata):
        by_node[str(row["node_id"])].append(index)
        event_id = str(row["event_id"])
        if event_id:
            grouped[event_id].append(index)

    incident_events = {
        event_id: indices
        for event_id, indices in grouped.items()
        if any(truth[index] != LABEL_TO_INDEX["BENIGN"] for index in indices)
    }
    detected = sum(
        any(predictions[index] != LABEL_TO_INDEX["BENIGN"] for index in indices)
        for indices in incident_events.values()
    )
    missed = len(incident_events) - detected
    delays = []
    availability_leads = []
    availability_events = {
        event_id: indices
        for event_id, indices in incident_events.items()
        if any(
            truth[index] == LABEL_TO_INDEX["AVAILABILITY_ANOMALY"]
            for index in indices
        )
    }
    node_event_starts: dict[str, list[int]] = defaultdict(list)
    for indices in availability_events.values():
        if indices:
            node_event_starts[str(metadata[indices[0]]["node_id"])].append(
                min(indices, key=lambda index: int(metadata[index]["node_index"]))
            )
    for indices in incident_events.values():
        start = min(indices, key=lambda index: int(metadata[index]["node_index"]))
        candidates = [
            index
            for index in indices
            if predictions[index] != LABEL_TO_INDEX["BENIGN"]
        ]
        if candidates:
            first = min(candidates, key=lambda index: int(metadata[index]["node_index"]))
            delays.append(
                (int(metadata[first]["node_index"]) - int(metadata[start]["node_index"]))
                * 60
            )
    for node_id, starts in node_event_starts.items():
        node_indices = by_node[node_id]
        for start in starts:
            start_position = int(metadata[start]["node_index"])
            before = [
                index
                for index in node_indices
                if start_position - FORECAST_HORIZON_WINDOWS
                <= int(metadata[index]["node_index"])
                < start_position
                and risk_probabilities[index] >= risk_threshold
            ]
            if before:
                first = min(
                    before, key=lambda index: int(metadata[index]["node_index"])
                )
                availability_leads.append(
                    (start_position - int(metadata[first]["node_index"])) * 60
                )

    false_alert_episodes = 0
    total_node_hours = 0.0
    for indices in by_node.values():
        indices.sort(key=lambda index: int(metadata[index]["node_index"]))
        total_node_hours += len(indices) / 60
        previous_alert = False
        for index in indices:
            is_alert = predictions[index] != LABEL_TO_INDEX["BENIGN"]
            if (
                is_alert
                and not previous_alert
                and truth[index] == LABEL_TO_INDEX["BENIGN"]
            ):
                false_alert_episodes += 1
            previous_alert = is_alert

    def wilson_interval(successes: int, total: int) -> list[float] | None:
            if total == 0:
                return None
            z = 1.96
            proportion = successes / total
            denominator = 1 + z * z / total
            center = (proportion + z * z / (2 * total)) / denominator
            margin = (
                z
                * math.sqrt(
                    proportion * (1 - proportion) / total
                    + z * z / (4 * total * total)
                )
                / denominator
            )
            return [max(0.0, center - margin), min(1.0, center + margin)]

    return {
        "incident_count": len(incident_events),
        "detected_incidents": detected,
        "missed_incidents": missed,
        "event_recall": detected / len(incident_events) if incident_events else None,
        "event_recall_wilson_95pct": wilson_interval(
            detected, len(incident_events)
        ),
        "false_alert_episodes": false_alert_episodes,
        "false_alerts_per_node_hour": (
            false_alert_episodes / total_node_hours if total_node_hours else None
        ),
        "false_alerts_per_node_day": (
            false_alert_episodes / (total_node_hours / 24)
            if total_node_hours
            else None
        ),
        "median_detection_delay_seconds": (
            float(np.median(delays)) if delays else None
        ),
        "median_forecast_lead_time_seconds": (
            float(np.median(availability_leads)) if availability_leads else None
        ),
        "availability_event_count": len(availability_events),
        "availability_events_with_forecast": len(availability_leads),
        "availability_events_without_forecast": (
            len(availability_events) - len(availability_leads)
        ),
        "availability_forecast_recall": (
            len(availability_leads) / len(availability_events)
            if availability_events
            else None
        ),
        "availability_forecast_recall_wilson_95pct": wilson_interval(
            len(availability_leads), len(availability_events)
        ),
    }


def _per_site_metrics(
    metadata: list[dict[str, object]],
    truth: np.ndarray,
    predictions: np.ndarray,
) -> dict[str, object]:
    grouped: dict[str, list[int]] = defaultdict(list)
    for index, row in enumerate(metadata):
        grouped[str(row["node_id"])].append(index)
    results = {}
    for node_id, indices in sorted(grouped.items()):
        precision, recall, f1, support = precision_recall_fscore_support(
            truth[indices],
            predictions[indices],
            labels=range(len(LABELS)),
            zero_division=0,
        )
        results[node_id] = {
            "window_count": len(indices),
            "macro_f1": float(np.mean(f1)),
            "per_class": {
                label: {
                    "precision": float(precision[class_index]),
                    "recall": float(recall[class_index]),
                    "f1": float(f1[class_index]),
                    "support": int(support[class_index]),
                }
                for class_index, label in enumerate(LABELS)
            },
            "incident_count": len(
                {
                    str(metadata[index]["event_id"])
                    for index in indices
                    if metadata[index]["event_id"]
                }
            ),
        }
    return results


def _node_bootstrap_interval(
    metadata: list[dict[str, object]],
    truth: np.ndarray,
    predictions: np.ndarray,
    seed: int = SEED,
) -> list[float] | None:
    node_indices: dict[str, list[int]] = defaultdict(list)
    for index, row in enumerate(metadata):
        node_indices[str(row["node_id"])].append(index)
    if len(node_indices) < 2:
        return None
    rng = np.random.default_rng(seed)
    nodes = list(node_indices)
    scores = []
    for _ in range(500):
        selected = rng.choice(nodes, size=len(nodes), replace=True)
        indices = [index for node in selected for index in node_indices[str(node)]]
        scores.append(
            f1_score(
                truth[indices],
                predictions[indices],
                labels=range(len(LABELS)),
                average="macro",
                zero_division=0,
            )
        )
    return [float(np.quantile(scores, 0.025)), float(np.quantile(scores, 0.975))]


def _hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _git_revision(repository: Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(repository), "rev-parse", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unavailable"


def _working_tree_source_hash() -> str:
    digest = hashlib.sha256()
    for path in (
        Path(__file__).with_name("threat_monitor_data.py"),
        Path(__file__),
    ):
        digest.update(path.name.encode("utf-8"))
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(chunk)
    return digest.hexdigest()


def run_evaluation(
    dataset_path: Path,
    output_directory: Path,
    *,
    sequence_length: int = SEQUENCE_LENGTH,
    seed: int = SEED,
) -> dict[str, object]:
    if sequence_length != SEQUENCE_LENGTH:
        raise ValueError("The evaluation config fixes input windows at 10 minutes.")
    output_directory.mkdir(parents=True, exist_ok=True)
    source_splits = _read_split(dataset_path)
    splits = {name: _build_sequences(rows) for name, rows in source_splits.items()}
    training, validation, testing = (
        splits["train"],
        splits["validation"],
        splits["test"],
    )
    y_train = training["labels"]
    y_validation = validation["labels"]
    y_test = testing["labels"]
    train_sequences = training["sequences"]
    validation_sequences = validation["sequences"]
    test_sequences = testing["sequences"]

    train_current = train_sequences[:, -1, :]
    validation_current = validation_sequences[:, -1, :]
    test_current = test_sequences[:, -1, :]
    train_temporal = train_sequences.reshape(len(train_sequences), -1)
    validation_temporal = validation_sequences.reshape(len(validation_sequences), -1)
    test_temporal = test_sequences.reshape(len(test_sequences), -1)

    tree = HistGradientBoostingClassifier(
        max_iter=100,
        max_leaf_nodes=15,
        learning_rate=0.08,
        l2_regularization=1.0,
        random_state=seed,
    )
    tree.fit(train_current, y_train)
    tree_validation = _aligned_probabilities(tree, validation_current)
    tree_calibrator = _fit_probability_calibrator(
        tree_validation, y_validation, seed
    )
    tree_validation_calibrated = _apply_calibrator(
        tree_calibrator, tree_validation
    )

    scaler = StandardScaler()
    scaler.fit(train_temporal)
    temporal_train_scaled = scaler.transform(train_temporal)
    temporal_validation_scaled = scaler.transform(validation_temporal)
    temporal_test_scaled = scaler.transform(test_temporal)
    temporal = MLPClassifier(
        hidden_layer_sizes=(64,),
        activation="relu",
        solver="adam",
        alpha=0.001,
        batch_size=128,
        learning_rate_init=0.001,
        max_iter=80,
        early_stopping=False,
        random_state=seed,
    )
    temporal.fit(temporal_train_scaled, y_train)
    temporal_validation = _aligned_probabilities(
        temporal, temporal_validation_scaled
    )
    temporal_calibrator = _fit_probability_calibrator(
        temporal_validation, y_validation, seed
    )
    temporal_validation_calibrated = _apply_calibrator(
        temporal_calibrator, temporal_validation
    )

    thresholds = {}
    validation_scores = {}
    for name, probabilities in (
        ("tree", tree_validation_calibrated),
        ("temporal", temporal_validation_calibrated),
    ):
        threshold, score = _abstain_threshold(probabilities, y_validation)
        thresholds[name] = threshold
        validation_scores[name] = score

    ood_detector = IsolationForest(
        n_estimators=100, contamination=0.01, random_state=seed
    )
    ood_detector.fit(train_current)
    tree_test_raw = _aligned_probabilities(tree, test_current)
    temporal_test_raw = _aligned_probabilities(temporal, temporal_test_scaled)
    tree_test_probabilities = _apply_calibrator(tree_calibrator, tree_test_raw)
    temporal_test_probabilities = _apply_calibrator(
        temporal_calibrator, temporal_test_raw
    )
    test_ood = ood_detector.predict(test_current) < 0

    risk_tree = HistGradientBoostingClassifier(
        max_iter=100,
        max_leaf_nodes=15,
        learning_rate=0.08,
        l2_regularization=1.0,
        random_state=seed,
    )
    risk_tree.fit(train_current, training["future_availability"])
    risk_validation = risk_tree.predict_proba(validation_current)[:, 1]
    risk_calibrator = LogisticRegression(max_iter=500, random_state=seed)
    risk_calibrator.fit(
        np.log(np.clip(risk_validation.reshape(-1, 1), 1e-7, 1)),
        validation["future_availability"],
    )
    risk_test_raw = risk_tree.predict_proba(test_current)[:, 1]
    risk_test = risk_calibrator.predict_proba(
        np.log(np.clip(risk_test_raw.reshape(-1, 1), 1e-7, 1))
    )[:, 1]
    risk_validation_calibrated = risk_calibrator.predict_proba(
        np.log(np.clip(risk_validation.reshape(-1, 1), 1e-7, 1))
    )[:, 1]
    risk_truth_validation = validation["future_availability"]
    risk_threshold = max(
        (
            threshold
            for threshold in (0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8)
        ),
        key=lambda threshold: f1_score(
            risk_truth_validation,
            risk_validation_calibrated >= threshold,
            zero_division=0,
        ),
    )

    rule_predictions, rule_probabilities, rule_config = _rule_predictions(
        training, testing
    )
    candidate_results: dict[str, object] = {}
    prediction_sets: dict[str, np.ndarray] = {
        "rules": rule_predictions,
    }
    probability_sets: dict[str, np.ndarray] = {
        "rules": rule_probabilities,
        "tree": tree_test_probabilities,
        "temporal": temporal_test_probabilities,
    }
    for name, probabilities in (
        ("tree", tree_test_probabilities),
        ("temporal", temporal_test_probabilities),
    ):
        predictions = _prediction_labels(
            probabilities, thresholds[name], ood=test_ood
        )
        prediction_sets[name] = predictions

    truth_metadata = testing["metadata"]
    for name, predictions in prediction_sets.items():
        probabilities = probability_sets[name]
        start = time.perf_counter()
        if name == "rules":
            _rule_predictions(training, testing)
        elif name == "tree":
            tree.predict_proba(test_current)
        else:
            temporal.predict_proba(temporal_test_scaled)
        latency_ms = (time.perf_counter() - start) * 1000 / len(y_test)
        metrics = _classification_metrics(
            y_test,
            predictions,
            probabilities,
            scores_are_probabilities=name != "rules",
        )
        metrics.update(
            _event_metrics(
                truth_metadata,
                y_test,
                predictions,
                risk_test,
                risk_threshold,
            )
        )
        metrics["macro_f1_node_bootstrap_95pct"] = _node_bootstrap_interval(
            truth_metadata, y_test, predictions, seed
        )
        metrics["per_site"] = _per_site_metrics(
            truth_metadata, y_test, predictions
        )
        metrics["inference_latency_ms_per_window"] = latency_ms
        if name in thresholds:
            metrics["validation_selected_abstain_threshold"] = thresholds[name]
            metrics["validation_macro_f1_at_selected_threshold"] = (
                validation_scores[name]
            )
            metrics["ood_windows_abstained"] = int(test_ood.sum())
        candidate_results[name] = metrics

    risk_metrics = {
        "forecast_horizon_minutes": FORECAST_HORIZON_WINDOWS,
        "validation_selected_threshold": risk_threshold,
        "pr_auc": None,
        "brier_score": float(
            np.mean(
                (
                    risk_test
                    - testing["future_availability"].astype(np.float64)
                )
                ** 2
            )
        ),
        "positive_windows": int(testing["future_availability"].sum()),
        "negative_windows": int(
            len(testing["future_availability"])
            - testing["future_availability"].sum()
        ),
    }
    risk_precision, risk_recall, _ = precision_recall_curve(
        testing["future_availability"], risk_test
    )
    risk_metrics["pr_auc"] = float(auc(risk_recall, risk_precision))

    artifacts = {
        "tree": {
            "model": tree,
            "calibrator": tree_calibrator,
            "features": FEATURES,
            "labels": LABELS,
            "abstain_threshold": thresholds["tree"],
        },
        "temporal": {
            "model": temporal,
            "scaler": scaler,
            "calibrator": temporal_calibrator,
            "features": FEATURES,
            "labels": LABELS,
            "sequence_length": SEQUENCE_LENGTH,
            "abstain_threshold": thresholds["temporal"],
        },
        "risk": {
            "model": risk_tree,
            "calibrator": risk_calibrator,
            "features": FEATURES,
            "forecast_horizon_minutes": FORECAST_HORIZON_WINDOWS,
        },
        "ood": ood_detector,
    }
    artifact_directory = output_directory / "artifacts"
    artifact_directory.mkdir(exist_ok=True)
    artifact_hashes: dict[str, str] = {}
    for name, artifact in artifacts.items():
        artifact_path = artifact_directory / f"{name}.joblib"
        joblib.dump(artifact, artifact_path)
        artifact_hashes[name] = _hash_file(artifact_path)

    predictions_path = output_directory / "test_predictions.csv"
    with predictions_path.open("w", encoding="utf-8", newline="") as target:
        fields = [
            "node_id",
            "timestamp",
            "event_id",
            "true_label",
            "rules_label",
            "tree_label",
            "tree_confidence",
            "temporal_label",
            "temporal_confidence",
            "out_of_distribution",
            "risk_within_forecast_horizon",
            "true_risk_within_forecast_horizon",
            "forecast_risk_alert",
        ]
        writer = csv.DictWriter(target, fieldnames=fields)
        writer.writeheader()
        for index, metadata in enumerate(truth_metadata):
            tree_abstained = (
                test_ood[index]
                or tree_test_probabilities[index].max() < thresholds["tree"]
            )
            temporal_abstained = (
                test_ood[index]
                or temporal_test_probabilities[index].max()
                < thresholds["temporal"]
            )
            writer.writerow(
                {
                    "node_id": metadata["node_id"],
                    "timestamp": metadata["timestamp"],
                    "event_id": metadata["event_id"],
                    "true_label": LABELS[int(y_test[index])],
                    "rules_label": LABELS[int(rule_predictions[index])],
                    "tree_label": LABELS[int(prediction_sets["tree"][index])],
                    "tree_confidence": (
                        None
                        if tree_abstained
                        else float(tree_test_probabilities[index].max())
                    ),
                    "temporal_label": LABELS[
                        int(prediction_sets["temporal"][index])
                    ],
                    "temporal_confidence": (
                        None
                        if temporal_abstained
                        else float(temporal_test_probabilities[index].max())
                    ),
                    "out_of_distribution": bool(test_ood[index]),
                    "risk_within_forecast_horizon": float(risk_test[index]),
                    "true_risk_within_forecast_horizon": int(
                        testing["future_availability"][index]
                    ),
                    "forecast_risk_alert": bool(risk_test[index] >= risk_threshold),
                }
            )

    manifest_path = dataset_path.with_suffix(dataset_path.suffix + ".manifest.json")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    repository = Path(__file__).resolve().parents[2]
    report = {
        "report_version": "threat-evaluation-v1",
        "evaluation_timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "evaluation_scope": "synthetic simulation only; not production efficacy",
        "dataset_version": manifest.get("dataset_version", DATASET_VERSION),
        "dataset_sha256": _hash_file(dataset_path),
        "dataset_manifest": manifest,
        "code_revision": _git_revision(repository),
        "code_worktree_source_sha256": _working_tree_source_hash(),
        "config": {
            "seed": seed,
            "sequence_length_minutes": SEQUENCE_LENGTH,
            "forecast_horizon_minutes": FORECAST_HORIZON_WINDOWS,
            "split_policy": (
                "disjoint synthetic sites plus chronological blocks; "
                "at least 10 excluded windows at time boundaries"
            ),
            "model_fit_data": "train split only",
            "calibration_and_threshold_data": "validation split only",
            "held_out_test_access": "single final evaluation",
            "rule_config": rule_config,
            "validation_macro_f1": validation_scores,
            "validation_risk_threshold_f1": float(
                f1_score(
                    risk_truth_validation,
                    risk_validation_calibrated >= risk_threshold,
                    zero_division=0,
                )
            ),
        },
        "split_window_counts": {
            name: int(len(split["labels"])) for name, split in splits.items()
        },
        "class_labels": list(LABELS),
        "candidate_results": candidate_results,
        "forecast_risk": risk_metrics,
        "artifact_sha256": artifact_hashes,
        "raw_test_predictions": predictions_path.name,
        "raw_test_predictions_sha256": _hash_file(predictions_path),
    }
    report_path = output_directory / "evaluation_report.json"
    report_path.write_text(json.dumps(report, indent=2, allow_nan=False), encoding="utf-8")
    return report


if __name__ == "__main__":
    import argparse

    default_data = (
        Path(__file__).resolve().parents[1]
        / "data"
        / "threat"
        / "generated"
        / f"{DATASET_VERSION}.csv"
    )
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", type=Path, default=default_data)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1]
        / "results"
        / "threat_monitor"
        / DATASET_VERSION,
    )
    arguments = parser.parse_args()
    result = run_evaluation(arguments.dataset, arguments.output)
    print(json.dumps(result, indent=2))
