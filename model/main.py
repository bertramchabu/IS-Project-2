import json
import math
import os
import threading
import time
from typing import Any

from firebase_functions import https_fn, options

MODEL_DIR = os.path.join(os.path.dirname(__file__), "models")
FEATURES = (
    "latency",
    "jitter",
    "packet_loss",
    "retransmission_rate",
    "signal_strength",
)
WINDOW_SIZE = 10
ALERT_THRESHOLD = 0.70
WARNING_THRESHOLD = 0.30
HEALTHY_SAMPLING_INTERVAL_SEC = 10.0

_assets_lock = threading.Lock()
_inference_lock = threading.Lock()
_interpreter: Any = None
_input_details: dict[str, Any] | None = None
_output_details: dict[str, Any] | None = None
_scaler: Any = None
_metadata: dict[str, Any] | None = None


def _load_assets() -> None:
    global _interpreter, _input_details, _output_details, _scaler, _metadata
    if _interpreter is not None:
        return

    with _assets_lock:
        if _interpreter is not None:
            return

        import joblib
        import numpy as np
        from tflite_runtime.interpreter import Interpreter

        interpreter = Interpreter(
            model_path=os.path.join(MODEL_DIR, "bilstm_fault_model.tflite"),
            num_threads=1,
        )
        interpreter.allocate_tensors()
        with open(
            os.path.join(MODEL_DIR, "model_metadata.json"),
            encoding="utf-8",
        ) as metadata_file:
            metadata = json.load(metadata_file)

        _scaler = joblib.load(os.path.join(MODEL_DIR, "scaler.joblib"))
        _input_details = interpreter.get_input_details()[0]
        _output_details = interpreter.get_output_details()[0]
        _metadata = metadata
        _interpreter = interpreter


def _require_authenticated(request: https_fn.CallableRequest) -> None:
    if request.auth is None:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="Sign in before using model inference.",
        )


def _metadata_value(key: str) -> Any:
    assert _metadata is not None
    return _metadata.get(key)


@https_fn.on_call(
    memory=options.MemoryOption.MB_512,
    timeout_sec=30,
    max_instances=5,
    region="us-central1",
)
def model_status(request: https_fn.CallableRequest) -> dict[str, Any]:
    _require_authenticated(request)
    try:
        _load_assets()
    except Exception as error:
        print(f"Model artifact loading failed: {error}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="The deployed model artifacts could not be loaded.",
        ) from error

    return {
        "online": True,
        "model_loaded": True,
        "model_version": _metadata_value("version_number") or "unknown",
        "f1_score": _metadata_value("f1_score"),
        "rmse": _metadata_value("rmse"),
        "features": list(FEATURES),
        "window_size": WINDOW_SIZE,
    }


@https_fn.on_call(
    memory=options.MemoryOption.MB_512,
    timeout_sec=30,
    max_instances=5,
    region="us-central1",
)
def predict_fault(request: https_fn.CallableRequest) -> dict[str, Any]:
    _require_authenticated(request)
    data = request.data
    if not isinstance(data, dict):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Request data must be an object.",
        )

    node_id = data.get("node_id")
    sequence = data.get("sequence")
    if not isinstance(node_id, str) or not node_id.strip():
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="A non-empty node_id is required.",
        )
    if not isinstance(sequence, list) or len(sequence) != WINDOW_SIZE:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message=f"sequence must contain exactly {WINDOW_SIZE} KPI samples.",
        )

    try:
        values = []
        for sample in sequence:
            if not isinstance(sample, dict):
                raise ValueError("Every sequence item must be an object.")
            row = [sample.get(feature) for feature in FEATURES]
            if any(
                not isinstance(value, (int, float))
                or isinstance(value, bool)
                or not math.isfinite(value)
                for value in row
            ):
                raise ValueError("Every KPI value must be a finite number.")
            values.append(row)
    except (TypeError, ValueError) as error:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message=str(error),
        ) from error

    try:
        import numpy as np

        _load_assets()
        assert _interpreter is not None
        assert _input_details is not None
        assert _output_details is not None
        assert _scaler is not None

        raw_sequence = np.asarray(values, dtype=np.float32)
        scaled_sequence = _scaler.transform(raw_sequence).astype(np.float32)
        input_shape = tuple(int(size) for size in _input_details["shape"])
        if math.prod(input_shape) != WINDOW_SIZE * len(FEATURES):
            raise ValueError(
                f"Model input shape {input_shape} does not match a "
                f"{WINDOW_SIZE}-step, {len(FEATURES)}-feature sequence."
            )

        model_input = scaled_sequence.reshape(input_shape)
        input_dtype = _input_details["dtype"]
        if np.issubdtype(input_dtype, np.integer):
            scale, zero_point = _input_details["quantization"]
            if scale <= 0:
                raise ValueError("Quantized model input has an invalid scale.")
            limits = np.iinfo(input_dtype)
            model_input = np.clip(
                np.rint(model_input / scale + zero_point),
                limits.min,
                limits.max,
            ).astype(input_dtype)
        else:
            model_input = model_input.astype(input_dtype)

        started_at = time.perf_counter()
        with _inference_lock:
            _interpreter.set_tensor(_input_details["index"], model_input)
            _interpreter.invoke()
            output = _interpreter.get_tensor(_output_details["index"])
        inference_latency_ms = (time.perf_counter() - started_at) * 1000

        probability = float(np.asarray(output).reshape(-1)[0])
        if not math.isfinite(probability) or not 0 <= probability <= 1:
            raise ValueError("Model returned a probability outside 0..1.")
    except Exception as error:
        print(f"Model inference failed for node {node_id}: {error}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="Model inference failed. Check the deployed model artifacts.",
        ) from error

    if probability >= ALERT_THRESHOLD:
        status, severity, alert_triggered = "CRITICAL_ALERT", "HIGH", True
        message = f"Fault probability {probability:.1%} exceeded the alert threshold."
    elif probability >= WARNING_THRESHOLD:
        status, severity, alert_triggered = "WARNING", "MEDIUM", False
        message = f"Degradation precursor detected ({probability:.1%})."
    else:
        status, severity, alert_triggered = "HEALTHY", "NORMAL", False
        message = (
            f"Fault probability is {probability:.1%}; sampling reduced to "
            f"every {HEALTHY_SAMPLING_INTERVAL_SEC:g} seconds."
        )

    healthy = probability < WARNING_THRESHOLD

    return {
        "node_id": node_id,
        "fault_probability": round(probability, 4),
        "status": status,
        "severity": severity,
        "alert_triggered": alert_triggered,
        "inference_latency_ms": round(inference_latency_ms, 2),
        "next_sampling_interval_sec": (
            HEALTHY_SAMPLING_INTERVAL_SEC if healthy else 1.0
        ),
        "computational_savings_percent": 90 if healthy else 0,
        "message": message,
        "timestamp": time.time(),
        "model_version": _metadata_value("version_number") or "unknown",
    }
