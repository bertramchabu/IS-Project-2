import hashlib
import json
import math
import os
import threading
import time
from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import uuid4

import firebase_admin
from firebase_admin import auth as firebase_auth
from firebase_admin import firestore
from firebase_functions import https_fn, options

firebase_admin.initialize_app(
    options={
        "projectId": os.environ.get("GCLOUD_PROJECT")
        or os.environ.get("GOOGLE_CLOUD_PROJECT")
        or "netvision-ai-0"
    }
)

MODEL_DIR = os.path.join(os.path.dirname(__file__), "models")
FEATURES = (
    "latency",
    "jitter",
    "packet_loss",
    "retransmission_rate",
    "signal_strength",
)
WINDOW_SIZE = 10
MANAGED_USER_ROLES = {
    "role_network_admin",
    "role_ict_manager",
    "role_system_admin",
}

_assets_lock = threading.Lock()
_inference_lock = threading.Lock()
_interpreter: Any = None
_input_details: dict[str, Any] | None = None
_output_details: dict[str, Any] | None = None
_scaler: Any = None
_metadata: dict[str, Any] | None = None
_scaler_version: str | None = None
_threat_tree: dict[str, Any] | None = None
_threat_risk: dict[str, Any] | None = None
_threat_ood: Any = None
_threshold_cache: dict[str, Any] | None = None
_threshold_cache_loaded_at = 0.0

THREAT_FEATURES = (
    "packets_per_sec",
    "bytes_per_sec",
    "flow_starts_per_sec",
    "inbound_outbound_ratio",
    "concurrent_connections",
    "total_connections",
    "failed_connections",
    "incomplete_connections",
    "average_connection_duration_seconds",
    "protocol_tcp",
    "protocol_udp",
    "protocol_icmp",
    "protocol_other",
    "top_destination_port_count",
    "top_destination_port_share",
    "tcp_syn_flag_count",
    "tcp_ack_flag_count",
    "tcp_rst_flag_count",
    "tcp_fin_flag_count",
    "source_address_entropy",
    "destination_address_entropy",
    "top_destination_share",
    "success_rate",
    "error_rate",
    "timeout_rate",
    "p95_latency_ms",
    "queue_saturation",
)
THREAT_MODEL_DIR = os.path.join(MODEL_DIR, "threat")
THREAT_MODEL_VERSION = "threat-synthetic-v1-tree"
THREAT_ARTIFACT_HASHES = {
    "tree.joblib": "1e70385b1c8c0532f8007137b52f70511a8f57edf2d01c85e97f717bba26b2a8",
    "risk.joblib": "5a7a92322faea3d7080403d3f7e2be2c20763ce96915c7c166014b4715326e71",
    "ood.joblib": "1a7b509680aee167c3574b96637e88b8dedfab1df0b0a597440c3f2b43eb6a54",
}


DEFAULT_THRESHOLD_CONFIG = {
    "globalThreshold": 0.70,
    "reductionThreshold": 0.30,
    "reductionPercentage": 90,
    "healthyInterval": 10.0,
    "adaptiveReductionEnabled": True,
}


def _validate_threshold_config(data: Any) -> dict[str, Any]:
    if not isinstance(data, dict):
        raise ValueError("Threshold configuration must be an object.")

    global_threshold = data.get("globalThreshold")
    reduction_threshold = data.get("reductionThreshold")
    reduction_percentage = data.get("reductionPercentage")
    healthy_interval = data.get("healthyInterval", 10.0)
    adaptive_reduction_enabled = data.get("adaptiveReductionEnabled", True)

    if (
        not isinstance(global_threshold, (int, float))
        or isinstance(global_threshold, bool)
        or not 0.5 <= float(global_threshold) <= 0.95
    ):
        raise ValueError("globalThreshold must be between 0.5 and 0.95.")
    if (
        not isinstance(reduction_threshold, (int, float))
        or isinstance(reduction_threshold, bool)
        or not 0.1 <= float(reduction_threshold) < float(global_threshold)
    ):
        raise ValueError(
            "reductionThreshold must be at least 0.1 and less than globalThreshold."
        )
    if (
        not isinstance(reduction_percentage, (int, float))
        or isinstance(reduction_percentage, bool)
        or not 50 <= float(reduction_percentage) <= 95
        or int(reduction_percentage) != float(reduction_percentage)
    ):
        raise ValueError("reductionPercentage must be an integer from 50 to 95.")
    if (
        not isinstance(healthy_interval, (int, float))
        or isinstance(healthy_interval, bool)
        or not 1 <= float(healthy_interval) <= 60
    ):
        raise ValueError("healthyInterval must be between 1 and 60 seconds.")
    if not isinstance(adaptive_reduction_enabled, bool):
        raise ValueError("adaptiveReductionEnabled must be a boolean.")

    return {
        "globalThreshold": float(global_threshold),
        "reductionThreshold": float(reduction_threshold),
        "reductionPercentage": int(reduction_percentage),
        "healthyInterval": float(healthy_interval),
        "adaptiveReductionEnabled": adaptive_reduction_enabled,
    }


def _threshold_config_version(data: dict[str, Any] | None) -> str:
    if not isinstance(data, dict):
        return "thresholds-v0"
    updated_at = data.get("updatedAt")
    if hasattr(updated_at, "timestamp"):
        try:
            timestamp = int(updated_at.timestamp())
            if timestamp >= 0:
                return f"thresholds-v{timestamp}"
        except (TypeError, ValueError, OverflowError):
            pass
    return "thresholds-v0"


def _load_thresholds(force: bool = False) -> tuple[dict[str, Any], str]:
    global _threshold_cache, _threshold_cache_loaded_at
    now = time.monotonic()
    if (
        not force
        and _threshold_cache is not None
        and now - _threshold_cache_loaded_at < 60
    ):
        return _threshold_cache, _threshold_config_version(_threshold_cache)

    try:
        snapshot = (
            firestore.client()
            .collection("systemConfig")
            .document("thresholds")
            .get()
        )
        document = snapshot.to_dict() if snapshot.exists else None
        if document is None:
            effective = dict(DEFAULT_THRESHOLD_CONFIG)
            version = "thresholds-v0"
        else:
            effective = _validate_threshold_config(document)
            effective["updatedAt"] = document.get("updatedAt")
            version = _threshold_config_version(document)
    except Exception as error:
        print(f"Threshold config load failed; using defaults: {error}")
        effective = dict(DEFAULT_THRESHOLD_CONFIG)
        effective["updatedAt"] = None
        version = "thresholds-v0"

    _threshold_cache = effective
    _threshold_cache_loaded_at = now
    return effective, version


def _load_assets() -> None:
    global _interpreter, _input_details, _output_details, _scaler, _metadata
    global _scaler_version
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

        scaler_path = os.path.join(MODEL_DIR, "scaler.joblib")
        _scaler = joblib.load(scaler_path)
        with open(scaler_path, "rb") as scaler_file:
            _scaler_version = hashlib.sha256(scaler_file.read()).hexdigest()
        _input_details = interpreter.get_input_details()[0]
        _output_details = interpreter.get_output_details()[0]
        _metadata = metadata
        _interpreter = interpreter


def _load_threat_assets() -> None:
    global _threat_tree, _threat_risk, _threat_ood
    if _threat_tree is not None and _threat_risk is not None and _threat_ood is not None:
        return

    with _assets_lock:
        if (
            _threat_tree is not None
            and _threat_risk is not None
            and _threat_ood is not None
        ):
            return

        import joblib

        assets: dict[str, Any] = {}
        for name, expected_hash in THREAT_ARTIFACT_HASHES.items():
            path = os.path.join(THREAT_MODEL_DIR, name)
            digest = hashlib.sha256()
            with open(path, "rb") as artifact_file:
                for chunk in iter(lambda: artifact_file.read(1024 * 1024), b""):
                    digest.update(chunk)
            if digest.hexdigest() != expected_hash:
                raise ValueError(f"Threat model artifact integrity check failed: {name}.")
            assets[name] = joblib.load(path)

        with open(
            os.path.join(THREAT_MODEL_DIR, "metadata.json"),
            encoding="utf-8",
        ) as metadata_file:
            metadata = json.load(metadata_file)
        if (
            metadata.get("model_version") != THREAT_MODEL_VERSION
            or metadata.get("simulation_only") is not True
            or metadata.get("artifact_sha256") != THREAT_ARTIFACT_HASHES
        ):
            raise ValueError("Threat model metadata does not match the packaged artifacts.")

        _threat_tree = assets["tree.joblib"]
        _threat_risk = assets["risk.joblib"]
        _threat_ood = assets["ood.joblib"]


def _threat_feature_vector(feature_window: Any) -> list[float]:
    if (
        not isinstance(feature_window, dict)
        or isinstance(feature_window.get("schemaVersion"), bool)
        or feature_window.get("schemaVersion") != 1
    ):
        raise ValueError("feature_window must use threat feature schema version 1.")
    data_quality_flags = feature_window.get("dataQualityFlags")
    if (
        feature_window.get("nodeId") != "SYNTHETIC-DEMO-NODE"
        or feature_window.get("serviceId") != "synthetic-edge-service"
        or not isinstance(data_quality_flags, list)
        or "synthetic_demo" not in data_quality_flags
    ):
        raise ValueError("Threat inference accepts only the labeled synthetic demo input.")
    window_start = _parse_utc_timestamp(feature_window.get("windowStartUtc"))
    window_end = _parse_utc_timestamp(feature_window.get("windowEndUtc"))
    if (
        window_start.second != 0
        or window_start.microsecond != 0
        or window_end - window_start != timedelta(seconds=60)
    ):
        raise ValueError("Threat feature windows must be UTC-aligned 60-second intervals.")

    def finite_number(value: Any, name: str) -> float:
        if (
            not isinstance(value, (int, float))
            or isinstance(value, bool)
            or not math.isfinite(value)
            or value < 0
        ):
            raise ValueError(f"{name} must be a finite non-negative number.")
        return float(value)

    rates = feature_window.get("rates")
    protocols = feature_window.get("protocolProportions")
    ports = feature_window.get("destinationPortCounts")
    tcp_flags = feature_window.get("tcpFlagCounts")
    if not all(isinstance(value, dict) for value in (rates, protocols, ports, tcp_flags)):
        raise ValueError("Threat rate, protocol, port, and TCP flag features are required.")

    port_counts = [
        finite_number(count, f"destinationPortCounts[{port}]")
        for port, count in ports.items()
    ]
    port_total = sum(port_counts)
    top_port_count = max(port_counts, default=0.0)
    vector = [
        finite_number(rates.get("packets_per_sec"), "packets_per_sec"),
        finite_number(rates.get("bytes_per_sec"), "bytes_per_sec"),
        finite_number(rates.get("flow_starts_per_sec"), "flow_starts_per_sec"),
        finite_number(rates.get("inbound_outbound_ratio"), "inbound_outbound_ratio"),
        finite_number(feature_window.get("concurrentConnections"), "concurrentConnections"),
        finite_number(feature_window.get("totalConnections"), "totalConnections"),
        finite_number(feature_window.get("failedConnections"), "failedConnections"),
        finite_number(feature_window.get("incompleteConnections"), "incompleteConnections"),
        finite_number(
            feature_window.get("averageConnectionDurationSeconds"),
            "averageConnectionDurationSeconds",
        ),
        *[
            finite_number(protocols.get(name), f"protocolProportions.{name}")
            for name in ("tcp", "udp", "icmp", "other")
        ],
        top_port_count,
        top_port_count / port_total if port_total else 0.0,
        *[
            finite_number(tcp_flags.get(name, 0), f"tcpFlagCounts.{name}")
            for name in ("SYN", "ACK", "RST", "FIN")
        ],
        finite_number(feature_window.get("sourceAddressEntropy"), "sourceAddressEntropy"),
        finite_number(
            feature_window.get("destinationAddressEntropy"),
            "destinationAddressEntropy",
        ),
        finite_number(feature_window.get("topDestinationShare"), "topDestinationShare"),
        finite_number(feature_window.get("successRate"), "successRate"),
        finite_number(feature_window.get("errorRate"), "errorRate"),
        finite_number(feature_window.get("timeoutRate"), "timeoutRate"),
        finite_number(feature_window.get("p95LatencyMs"), "p95LatencyMs"),
        finite_number(feature_window.get("queueSaturation"), "queueSaturation"),
    ]
    if len(vector) != len(THREAT_FEATURES):
        raise ValueError("Threat feature vector has an unexpected length.")
    return vector


def _require_threat_admin(request: https_fn.CallableRequest) -> dict[str, Any]:
    profile = _require_active_user(request)
    if profile.get("roleId") not in {"role_network_admin", "role_system_admin"}:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            message="Network or system administrator access is required for threat inference.",
        )
    return profile


def _require_authenticated(request: https_fn.CallableRequest) -> None:
    if request.auth is None:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="Sign in before using model inference.",
        )


def _require_active_user(request: https_fn.CallableRequest) -> dict[str, Any]:
    _require_authenticated(request)
    assert request.auth is not None
    try:
        profile = (
            firestore.client()
            .collection("users")
            .document(request.auth.uid)
            .get()
        )
    except Exception as error:
        print(f"Could not verify user profile {request.auth.uid}: {error}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="The user profile could not be verified.",
        ) from error

    profile_data = profile.to_dict() if profile.exists else None
    if not profile_data or profile_data.get("isActive", True) is not True:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            message="An active user profile is required.",
        )
    return profile_data


def _require_network_admin(request: https_fn.CallableRequest) -> dict[str, Any]:
    profile = _require_active_user(request)
    if profile.get("roleId") not in {"role_network_admin", "role_system_admin"}:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            message="Network administrator access is required for fault inference.",
        )
    return profile


def _parse_utc_timestamp(value: Any) -> datetime:
    if not isinstance(value, str):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="input_timestamp_utc must be an ISO-8601 UTC timestamp.",
        )
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="input_timestamp_utc must be a valid ISO-8601 timestamp.",
        ) from error
    if parsed.tzinfo is None or parsed.utcoffset() != timedelta(0):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="input_timestamp_utc must include the UTC timezone.",
        )
    return parsed.astimezone(timezone.utc)


def _normalize_managed_user(data: Any) -> dict[str, str | None]:
    if not isinstance(data, dict):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Request data must be an object.",
        )

    username = data.get("username")
    email = data.get("email")
    role_id = data.get("role_id")
    department = data.get("department")
    normalized_username = username.strip() if isinstance(username, str) else ""
    if not normalized_username or len(normalized_username) > 100:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="A username of 1 to 100 characters is required.",
        )
    normalized_email = email.strip().lower() if isinstance(email, str) else ""
    if (
        not normalized_email
        or len(normalized_email) > 254
        or "@" not in normalized_email
        or normalized_email.startswith("@")
        or normalized_email.endswith("@")
        or any(character.isspace() for character in normalized_email)
    ):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="A valid email address is required.",
        )
    if not isinstance(role_id, str) or role_id not in MANAGED_USER_ROLES:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="A supported user role is required.",
        )
    if department is not None and (
        not isinstance(department, str) or len(department) > 100
    ):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Department must be a string of at most 100 characters.",
        )

    return {
        "username": normalized_username,
        "email": normalized_email,
        "role_id": role_id,
        "department": department.strip() if department else None,
    }


def _require_system_admin(request: https_fn.CallableRequest) -> dict[str, Any]:
    profile = _require_active_user(request)
    if profile.get("roleId") != "role_system_admin":
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            message="System administrator access is required.",
        )
    return profile


def _metadata_value(key: str) -> Any:
    assert _metadata is not None
    return _metadata.get(key)


def _infer_threat_features(values: list[float]) -> dict[str, Any]:
    import numpy as np

    _load_threat_assets()
    assert _threat_tree is not None
    assert _threat_risk is not None
    assert _threat_ood is not None
    if tuple(_threat_tree["features"]) != THREAT_FEATURES:
        raise ValueError("Threat classifier feature order does not match the API.")
    if len(_threat_tree["labels"]) != 4:
        raise ValueError("Threat classifier label set does not match the API.")

    input_vector = np.asarray([values], dtype=np.float64)
    started_at = time.perf_counter()
    raw_probabilities = _threat_tree["model"].predict_proba(input_vector)
    labels = list(_threat_tree["labels"])
    aligned = np.zeros((1, len(labels)), dtype=np.float64)
    for column, label_index in enumerate(_threat_tree["model"].classes_):
        aligned[0, int(label_index)] = raw_probabilities[0, column]
    calibrated_raw = _threat_tree["calibrator"].predict_proba(
        np.log(np.clip(aligned, 1e-7, 1.0))
    )
    probabilities = np.zeros((1, len(labels)), dtype=np.float64)
    for column, label_index in enumerate(_threat_tree["calibrator"].classes_):
        probabilities[0, int(label_index)] = calibrated_raw[0, column]

    raw_risk = _threat_risk["model"].predict_proba(input_vector)
    risk_class = list(_threat_risk["model"].classes_).index(1)
    raw_risk_probability = raw_risk[:, risk_class]
    calibrated_risk = _threat_risk["calibrator"].predict_proba(
        np.log(np.clip(raw_risk_probability.reshape(-1, 1), 1e-7, 1.0))
    )
    risk_class = list(_threat_risk["calibrator"].classes_).index(1)
    risk_probability = float(calibrated_risk[0, risk_class])
    is_out_of_distribution = bool(_threat_ood.predict(input_vector)[0] < 0)
    inference_latency_ms = (time.perf_counter() - started_at) * 1000

    probabilities = probabilities[0]
    top_index = int(np.argmax(probabilities))
    top_probability = float(probabilities[top_index])
    is_abstained = (
        is_out_of_distribution
        or top_probability < float(_threat_tree["abstain_threshold"])
        or labels[top_index] == "UNKNOWN"
    )
    return {
        "category": "UNKNOWN" if is_abstained else labels[top_index],
        "confidence": None if is_abstained else round(top_probability, 6),
        "highest_class_probability": round(top_probability, 6),
        "risk_within_forecast_horizon": round(risk_probability, 6),
        "forecast_horizon_minutes": int(
            _threat_risk["forecast_horizon_minutes"]
        ),
        "out_of_distribution": is_out_of_distribution,
        "uncertainty_reason": (
            "Synthetic input is outside the model's training distribution."
            if is_out_of_distribution
            else "Model confidence did not meet the synthetic validation threshold."
            if is_abstained
            else None
        ),
        "inference_latency_ms": round(inference_latency_ms, 3),
    }


@https_fn.on_call(
    timeout_sec=30,
    max_instances=5,
    region="us-central1",
)
def create_managed_user(request: https_fn.CallableRequest) -> dict[str, str]:
    admin_profile = _require_system_admin(request)
    assert request.auth is not None
    user_data = _normalize_managed_user(request.data)
    created_user = None

    try:
        created_user = firebase_auth.create_user(
            email=user_data["email"],
            email_verified=False,
        )
        db = firestore.client()
        batch = db.batch()
        batch.create(
            db.collection("users").document(created_user.uid),
            {
                "username": user_data["username"],
                "email": user_data["email"],
                "roleId": user_data["role_id"],
                "department": user_data["department"],
                "isActive": True,
                "mfaEnabled": False,
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
        )
        batch.create(
            db.collection("auditLogs").document(),
            {
                "userId": request.auth.uid,
                "userName": admin_profile.get("username", request.auth.uid),
                "action": "USER_CREATED",
                "details": (
                    f"Created user {user_data['username']} "
                    f"({user_data['email']}) with role {user_data['role_id']}"
                ),
                "timestamp": firestore.SERVER_TIMESTAMP,
            },
        )
        batch.commit()
    except firebase_auth.EmailAlreadyExistsError as error:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.ALREADY_EXISTS,
            message="An account already exists for that email address.",
        ) from error
    except Exception as error:
        if created_user is not None:
            try:
                firebase_auth.delete_user(created_user.uid)
            except Exception as cleanup_error:
                print(
                    "Could not roll back incomplete user creation "
                    f"for {created_user.uid}: {cleanup_error}"
                )
        print(f"Managed user creation failed: {error}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="The user account could not be created.",
        ) from error

    return {
        "uid": created_user.uid,
        "email": user_data["email"] or "",
        "role_id": user_data["role_id"] or "",
    }


@https_fn.on_call(
    memory=options.MemoryOption.MB_512,
    timeout_sec=30,
    max_instances=5,
    region="us-central1",
)
def get_thresholds(request: https_fn.CallableRequest) -> dict[str, Any]:
    _require_system_admin(request)
    effective, version = _load_thresholds(force=True)
    return {
        "globalThreshold": effective["globalThreshold"],
        "adaptiveReductionEnabled": effective.get("adaptiveReductionEnabled", True),
        "reductionThreshold": effective["reductionThreshold"],
        "reductionPercentage": effective["reductionPercentage"],
        "healthyInterval": effective["healthyInterval"],
        "thresholdConfigVersion": version,
    }


@https_fn.on_call(
    memory=options.MemoryOption.MB_512,
    timeout_sec=30,
    max_instances=5,
    region="us-central1",
)
def set_thresholds(request: https_fn.CallableRequest) -> dict[str, Any]:
    _require_system_admin(request)
    assert request.auth is not None
    data = request.data
    if not isinstance(data, dict):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Threshold configuration must be an object.",
        )
    try:
        effective = _validate_threshold_config(data)
    except ValueError as error:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message=str(error),
        ) from error

    adaptive = effective["adaptiveReductionEnabled"]

    db = firestore.client()
    updated_at = datetime.now(timezone.utc)
    db.collection("systemConfig").document("thresholds").set(
        {
            **effective,
            "adaptiveReductionEnabled": adaptive,
            "updatedAt": updated_at,
            "updatedBy": request.auth.uid,
        },
        merge=True,
    )
    global _threshold_cache, _threshold_cache_loaded_at
    _threshold_cache = {
        **effective,
        "adaptiveReductionEnabled": adaptive,
        "updatedAt": updated_at,
    }
    _threshold_cache_loaded_at = time.monotonic()
    return {
        **effective,
        "adaptiveReductionEnabled": adaptive,
        "thresholdConfigVersion": _threshold_config_version(_threshold_cache),
    }


@https_fn.on_call(
    memory=options.MemoryOption.MB_512,
    timeout_sec=30,
    max_instances=5,
    region="us-central1",
)
def model_status(request: https_fn.CallableRequest) -> dict[str, Any]:
    _require_active_user(request)
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
        "supports_demo_only": True,
    }


@https_fn.on_call(
    memory=options.MemoryOption.MB_512,
    timeout_sec=30,
    max_instances=5,
    region="us-central1",
)
def threat_model_status(request: https_fn.CallableRequest) -> dict[str, Any]:
    _require_threat_admin(request)
    try:
        _load_threat_assets()
    except Exception as error:
        print(f"Synthetic threat model artifact loading failed: {error}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="The synthetic threat model artifacts could not be loaded.",
        ) from error

    return {
        "online": True,
        "model_loaded": True,
        "model_version": THREAT_MODEL_VERSION,
        "dataset_version": "threat-synthetic-v1",
        "simulation_only": True,
        "supports_demo_only": True,
        "classifier": "calibrated gradient-boosted tree",
        "forecast_horizon_minutes": 10,
        "input_features": list(THREAT_FEATURES),
    }


@https_fn.on_call(
    memory=options.MemoryOption.MB_512,
    timeout_sec=30,
    max_instances=5,
    region="us-central1",
)
def predict_threat(request: https_fn.CallableRequest) -> dict[str, Any]:
    _require_threat_admin(request)
    data = request.data
    if not isinstance(data, dict):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Request data must be an object.",
        )
    if data.get("demo_only") is not True:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message="This threat model is restricted to synthetic demo inference.",
        )

    try:
        values = _threat_feature_vector(data.get("feature_window"))
        prediction = _infer_threat_features(values)
    except (KeyError, TypeError, ValueError, IndexError) as error:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message=f"Invalid synthetic threat feature window: {error}",
        ) from error
    except Exception as error:
        print(f"Synthetic threat inference failed: {error}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="Synthetic threat inference failed.",
        ) from error

    return {
        **prediction,
        "model_version": THREAT_MODEL_VERSION,
        "dataset_version": "threat-synthetic-v1",
        "simulation_only": True,
        "persisted": False,
    }


@https_fn.on_call(
    memory=options.MemoryOption.MB_512,
    timeout_sec=30,
    max_instances=5,
    region="us-central1",
)
def predict_fault(request: https_fn.CallableRequest) -> dict[str, Any]:
    profile = _require_network_admin(request)
    assert request.auth is not None
    threshold_config, threshold_config_version = _load_thresholds()
    alert_threshold = threshold_config["globalThreshold"]
    warning_threshold = threshold_config["reductionThreshold"]
    healthy_sampling_interval = threshold_config["healthyInterval"]
    reduction_percentage = threshold_config["reductionPercentage"]
    adaptive_reduction_enabled = threshold_config["adaptiveReductionEnabled"]
    data = request.data
    if not isinstance(data, dict):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Request data must be an object.",
        )

    node_id = data.get("node_id")
    sequence = data.get("sequence")
    demo_only = data.get("demo_only", False)
    input_timestamp = _parse_utc_timestamp(data.get("input_timestamp_utc"))
    if not isinstance(demo_only, bool):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="demo_only must be a boolean.",
        )
    if not isinstance(node_id, str) or not node_id.strip():
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="A non-empty node_id is required.",
        )
    node_id = node_id.strip()
    if demo_only and not node_id.startswith("SYNTHETIC-DEMO-"):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="Demo-only fault inference requires a synthetic demo node ID.",
        )
    if not demo_only and node_id.startswith("SYNTHETIC-DEMO-"):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message="Synthetic demo predictions cannot be persisted as live records.",
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

    if probability >= alert_threshold:
        status, severity, alert_triggered = "CRITICAL_ALERT", "HIGH", True
        message = f"Fault probability {probability:.1%} exceeded the alert threshold."
    elif probability >= warning_threshold:
        status, severity, alert_triggered = "WARNING", "MEDIUM", False
        message = f"Degradation precursor detected ({probability:.1%})."
    else:
        status, severity, alert_triggered = "HEALTHY", "NORMAL", False
        message = (
            f"Fault probability is {probability:.1%}; sampling reduced to "
            f"every {healthy_sampling_interval:g} seconds."
            if adaptive_reduction_enabled
            else f"Fault probability is {probability:.1%}; adaptive reduction is disabled."
        )

    healthy = probability < warning_threshold and adaptive_reduction_enabled
    prediction_id = uuid4().hex
    prediction_timestamp = datetime.now(timezone.utc)
    model_version = _metadata_value("version_number") or "unknown"
    scaler_version = _metadata.get("scaler_version") or _scaler_version or "unknown"
    inference_result = {
        "node_id": node_id,
        "fault_probability": round(probability, 4),
        "status": status,
        "severity": severity,
        "alert_triggered": alert_triggered,
        "inference_latency_ms": round(inference_latency_ms, 2),
        "next_sampling_interval_sec": (
            healthy_sampling_interval if healthy else 1.0
        ),
        "adaptive_reduction_applied": healthy,
        "computational_savings_percent": reduction_percentage if healthy else 0,
        "message": message,
        "timestamp": prediction_timestamp.timestamp(),
        "prediction_id": prediction_id,
        "input_timestamp_utc": input_timestamp.isoformat(),
        "model_version": model_version,
        "thresholdConfigVersion": threshold_config_version,
    }

    if demo_only:
        inference_result["prediction_id"] = None
        inference_result["alert_created"] = False
        inference_result["would_trigger_alert"] = alert_triggered
        inference_result["simulation_only"] = True
        inference_result["demo_only"] = True
        return inference_result

    input_window = [
        {feature: value for feature, value in zip(FEATURES, row)}
        for row in values
    ]
    evidence_payload = {
        "modelInputWindowReference": prediction_id,
        "nodeId": node_id,
        "sourceTimestampUtc": input_timestamp.isoformat(),
        "modelInputWindow": input_window,
        "modelVersion": model_version,
        "scalerVersion": scaler_version,
        "thresholdConfigVersion": threshold_config_version,
        "thresholds": {
            "warning": warning_threshold,
            "alert": alert_threshold,
        },
        "inferenceResult": inference_result,
        "inferenceTimestampUtc": prediction_timestamp.isoformat(),
        "inferenceLatencyMs": round(inference_latency_ms, 2),
    }
    payload_json = json.dumps(
        evidence_payload,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    )
    evidence = {
        "recordType": "fault_inference",
        "timestampUtc": prediction_timestamp,
        "ingestionTimeUtc": firestore.SERVER_TIMESTAMP,
        "actorUserId": request.auth.uid,
        "resourceId": prediction_id,
        "payloadJson": payload_json,
        "payloadHashSha256": hashlib.sha256(payload_json.encode("utf-8")).hexdigest(),
        "modelVersion": str(model_version),
        "scalerVersion": str(scaler_version),
        "thresholdConfigVersion": threshold_config_version,
        "dataQualityFlags": [],
    }

    db = firestore.client()
    prediction_ref = (
        db.collection("networkNodes")
        .document(node_id)
        .collection("predictions")
        .document(prediction_id)
    )
    evidence_ref = db.collection("forensicEvidence").document(prediction_id)
    prediction_document = {
        "nodeId": node_id,
        "modelVersionId": str(model_version),
        "faultProbability": round(probability, 4),
        "inputFeatures": values[-1],
        "inferenceTimeMs": round(inference_latency_ms, 2),
        "adaptiveReductionApplied": healthy,
        "predictionTimestamp": prediction_timestamp,
        "inputTimestamp": input_timestamp,
        "triggeredBy": "Firebase BiLSTM Function",
        "status": status,
        "message": message,
        "alertTriggered": alert_triggered,
        "computationalSavingsPercent": reduction_percentage if healthy else 0,
        "nextSamplingIntervalSeconds": (
            healthy_sampling_interval if healthy else 1.0
        ),
        "modelF1Score": _metadata_value("f1_score"),
        "modelRmse": _metadata_value("rmse"),
    }

    batch = db.batch()
    batch.create(prediction_ref, prediction_document)
    batch.create(evidence_ref, evidence)
    alert_created = False
    if alert_triggered:
        recent_alerts = (
            db.collection("networkNodes")
            .document(node_id)
            .collection("alerts")
            .where("severityId", "==", "critical")
            .where(
                "createdAt",
                ">",
                prediction_timestamp - timedelta(minutes=5),
            )
            .order_by("createdAt", direction=firestore.Query.DESCENDING)
            .limit(20)
            .get()
        )
        if not any(alert.get("status") == "Active" for alert in recent_alerts):
            alert_ref = (
                db.collection("networkNodes")
                .document(node_id)
                .collection("alerts")
                .document(prediction_id)
            )
            batch.create(
                alert_ref,
                {
                    "nodeId": node_id,
                    "predictionId": prediction_id,
                    "severityId": "critical",
                    "status": "Active",
                    "title": f"Predicted fault on {node_id}",
                    "description": message,
                    "faultProbability": round(probability, 4),
                    "modelVersionId": str(model_version),
                    "createdAt": prediction_timestamp,
                },
            )
            batch.create(
                db.collection("auditLogs").document(),
                {
                    "userId": request.auth.uid,
                    "userName": profile.get("username", request.auth.uid),
                    "action": "ALERT_CREATED",
                    "details": (
                        f"Fault alert {prediction_id} created for {node_id}; "
                        f"probability {probability:.4f}."
                    ),
                    "timestamp": prediction_timestamp,
                },
            )
            alert_created = True

    try:
        batch.commit()
    except Exception as error:
        print(f"Could not persist fault inference for {node_id}: {error}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="The fault inference could not be persisted.",
        ) from error

    inference_result["alert_created"] = alert_created
    return inference_result
