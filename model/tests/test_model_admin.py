import unittest
from datetime import timedelta
from unittest.mock import patch

from firebase_functions import https_fn

from main import (
    THREAT_FEATURES,
    _infer_threat_features,
    _load_threat_assets,
    _normalize_managed_user,
    _parse_utc_timestamp,
    _require_network_admin,
    _require_threat_admin,
    _threat_feature_vector,
)


class ManagedUserValidationTests(unittest.TestCase):
    def test_normalizes_email_and_optional_department(self) -> None:
        user = _normalize_managed_user(
            {
                "username": "  Net Admin ",
                "email": " ADMIN@EXAMPLE.COM ",
                "role_id": "role_network_admin",
                "department": "  Operations ",
            }
        )

        self.assertEqual(user["username"], "Net Admin")
        self.assertEqual(user["email"], "admin@example.com")
        self.assertEqual(user["role_id"], "role_network_admin")
        self.assertEqual(user["department"], "Operations")

    def test_rejects_unsupported_roles_and_invalid_email(self) -> None:
        for data in (
            {
                "username": "User",
                "email": "user@example.com",
                "role_id": "owner",
            },
            {
                "username": "User",
                "email": "not-an-email",
                "role_id": "role_ict_manager",
            },
        ):
            with self.subTest(data=data), self.assertRaises(https_fn.HttpsError):
                _normalize_managed_user(data)


class UtcTimestampValidationTests(unittest.TestCase):
    def test_normalizes_z_and_zero_offset_timestamps_to_utc(self) -> None:
        zulu = _parse_utc_timestamp("2026-10-22T12:30:00Z")
        offset = _parse_utc_timestamp("2026-10-22T12:30:00+00:00")

        self.assertEqual(zulu.utcoffset(), timedelta(0))
        self.assertEqual(offset, zulu)

    def test_rejects_timestamps_without_explicit_utc_offset(self) -> None:
        for value in ("2026-10-22T12:30:00", "2026-10-22T12:30:00+03:00"):
            with self.subTest(value=value), self.assertRaises(https_fn.HttpsError):
                _parse_utc_timestamp(value)


class FaultInferenceAccessTests(unittest.TestCase):
    def test_allows_only_network_and_system_admin_profiles(self) -> None:
        for role_id in ("role_network_admin", "role_system_admin"):
            with self.subTest(role_id=role_id), patch(
                "main._require_active_user",
                return_value={"roleId": role_id},
            ):
                self.assertEqual(
                    _require_network_admin(object())["roleId"],
                    role_id,
                )

        with patch(
            "main._require_active_user",
            return_value={"roleId": "role_ict_manager"},
        ):
            with self.assertRaises(https_fn.HttpsError):
                _require_network_admin(object())

    def test_threat_model_access_is_limited_to_network_and_system_admins(self) -> None:
        for role_id in ("role_network_admin", "role_system_admin"):
            with self.subTest(role_id=role_id), patch(
                "main._require_active_user",
                return_value={"roleId": role_id},
            ):
                self.assertEqual(
                    _require_threat_admin(object())["roleId"],
                    role_id,
                )

        with patch(
            "main._require_active_user",
            return_value={"roleId": "role_ict_manager"},
        ):
            with self.assertRaises(https_fn.HttpsError):
                _require_threat_admin(object())


class ThreatInferenceInputTests(unittest.TestCase):
    def _synthetic_window(self) -> dict[str, object]:
        return {
            "schemaVersion": 1,
            "nodeId": "SYNTHETIC-DEMO-NODE",
            "serviceId": "synthetic-edge-service",
            "windowStartUtc": "2026-11-13T10:00:00Z",
            "windowEndUtc": "2026-11-13T10:01:00Z",
            "rates": {
                "packets_per_sec": 6.5,
                "bytes_per_sec": 200,
                "flow_starts_per_sec": 0.2,
                "inbound_outbound_ratio": 1.5,
            },
            "concurrentConnections": 2,
            "totalConnections": 12,
            "failedConnections": 0,
            "incompleteConnections": 0,
            "averageConnectionDurationSeconds": 2,
            "protocolProportions": {
                "tcp": 1,
                "udp": 0,
                "icmp": 0,
                "other": 0,
            },
            "destinationPortCounts": {"443": 12},
            "tcpFlagCounts": {"SYN": 12, "ACK": 12},
            "sourceAddressEntropy": 3.5,
            "destinationAddressEntropy": 2.2,
            "topDestinationShare": 1,
            "successRate": 1,
            "errorRate": 0,
            "timeoutRate": 0,
            "p95LatencyMs": 45,
            "queueSaturation": 0.1,
            "dataQualityFlags": ["synthetic_demo"],
        }

    def test_builds_exact_ordered_vector_from_labeled_synthetic_window(self) -> None:
        vector = _threat_feature_vector(self._synthetic_window())

        self.assertEqual(len(vector), len(THREAT_FEATURES))
        self.assertEqual(vector[:4], [6.5, 200, 0.2, 1.5])
        self.assertEqual(vector[9:13], [1, 0, 0, 0])
        self.assertEqual(vector[13:15], [12, 1])
        self.assertEqual(vector[-2:], [45, 0.1])

    def test_rejects_unlabeled_or_misaligned_nonsynthetic_input(self) -> None:
        for mutate in (
            lambda window: window.update(dataQualityFlags=[]),
            lambda window: window.update(nodeId="router-1"),
            lambda window: window.update(windowEndUtc="2026-11-13T10:02:00Z"),
        ):
            window = self._synthetic_window()
            mutate(window)
            with self.subTest(window=window), self.assertRaises(ValueError):
                _threat_feature_vector(window)

    def test_loads_hash_pinned_synthetic_model_artifacts(self) -> None:
        _load_threat_assets()

    def test_runs_cloud_candidate_and_risk_model_on_synthetic_window(self) -> None:
        prediction = _infer_threat_features(
            _threat_feature_vector(self._synthetic_window())
        )

        self.assertIn(
            prediction["category"],
            {"BENIGN", "AVAILABILITY_ANOMALY", "OPERATIONAL_FAULT", "UNKNOWN"},
        )
        self.assertGreaterEqual(prediction["risk_within_forecast_horizon"], 0)
        self.assertLessEqual(prediction["risk_within_forecast_horizon"], 1)
        if prediction["category"] == "UNKNOWN":
            self.assertIsNone(prediction["confidence"])
            self.assertIsNotNone(prediction["uncertainty_reason"])
        else:
            self.assertGreaterEqual(prediction["confidence"], 0)
            self.assertLessEqual(prediction["confidence"], 1)


if __name__ == "__main__":
    unittest.main()
