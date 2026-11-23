"""State transitions and subprocess execution for NetVision retraining."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Iterable


MODEL_DIR = Path(__file__).resolve().parents[1]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def run_command(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=3600,
        check=False,
    )


def evaluate_result(result_directory: Path) -> dict:
    report_path = result_directory / "evaluation_report.json"
    if not report_path.exists():
        raise FileNotFoundError(report_path)
    report = json.loads(report_path.read_text(encoding="utf-8"))
    metrics = report.get("metrics", {})
    return {
        "f1": metrics.get("f1_score"),
        "rmse": metrics.get("rmse"),
        "report": report,
    }


def artifact_hashes(model_directory: Path) -> dict[str, str]:
    names = (
        "bilstm_fault_model.keras",
        "bilstm_fault_model.tflite",
        "scaler.joblib",
        "model_metadata.json",
    )
    return {
        name: sha256_file(model_directory / name)
        for name in names
        if (model_directory / name).exists()
    }


def dry_run(request_id: str = "dry-run-request") -> dict:
    transitions = [
        {"request_id": request_id, "status": "in_progress"},
        {"request_id": request_id, "status": "completed", "stub": True},
    ]
    return {
        "dry_run": True,
        "request_id": request_id,
        "transitions": transitions,
        "hashes": {"dry-run": "not-computed"},
    }


def execute(dataset_path: Path, dry_run_mode: bool = False) -> dict:
    if dry_run_mode:
        return dry_run()
    if not dataset_path.exists():
        raise FileNotFoundError(dataset_path)

    train = run_command(
        [sys.executable, "-m", "src.train", "--dataset", str(dataset_path)],
        MODEL_DIR,
    )
    if train.returncode != 0:
        raise RuntimeError(
            "Training failed:\n" + (train.stderr or train.stdout)[-4096:]
        )

    evaluate = run_command(
        [sys.executable, "-m", "src.evaluate"],
        MODEL_DIR,
    )
    if evaluate.returncode != 0:
        raise RuntimeError(
            "Evaluation failed:\n" + (evaluate.stderr or evaluate.stdout)[-4096:]
        )

    evaluation = evaluate_result(MODEL_DIR / "results")
    return {
        "dry_run": False,
        "dataset_path": str(dataset_path),
        "f1": evaluation["f1"],
        "rmse": evaluation["rmse"],
        "artifact_sha256": artifact_hashes(MODEL_DIR / "models"),
        "metadata": json.loads(
            (MODEL_DIR / "models" / "model_metadata.json").read_text(
                encoding="utf-8"
            )
        ),
        "evaluation_report": evaluation["report"],
    }


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--request-id", default="dry-run-request")
    parser.add_argument(
        "--dataset",
        default=str(MODEL_DIR / "data" / "network_kpi_dataset.csv"),
    )
    args = parser.parse_args(list(argv) if argv is not None else None)
    output = execute(Path(args.dataset), dry_run_mode=args.dry_run)
    print(json.dumps(output, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
