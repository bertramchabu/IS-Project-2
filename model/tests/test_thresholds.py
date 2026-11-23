import unittest
from datetime import datetime, timezone

from main import (
    DEFAULT_THRESHOLD_CONFIG,
    _threshold_config_version,
    _validate_threshold_config,
)


class ThresholdValidationTests(unittest.TestCase):
    def valid(self):
        return {
            **DEFAULT_THRESHOLD_CONFIG,
            "globalThreshold": 0.70,
            "reductionThreshold": 0.30,
            "reductionPercentage": 90,
            "healthyInterval": 10.0,
        }

    def test_accepts_bounds_and_defaults(self):
        self.assertEqual(_validate_threshold_config(self.valid()), self.valid())
        self.assertEqual(
            _validate_threshold_config({
                "globalThreshold": 0.95,
                "reductionThreshold": 0.10,
                "reductionPercentage": 50,
                "healthyInterval": 60,
            })["healthyInterval"],
            60,
        )

    def test_rejects_out_of_bounds_values(self):
        invalid = (
            {"globalThreshold": 0.49},
            {"globalThreshold": 0.96},
            {"reductionThreshold": 0.70, "globalThreshold": 0.70},
            {"reductionPercentage": 49},
            {"reductionPercentage": 96},
            {"healthyInterval": 0},
            {"healthyInterval": 61},
        )
        for override in invalid:
            with self.subTest(override=override):
                data = self.valid()
                data.update(override)
                with self.assertRaises(ValueError):
                    _validate_threshold_config(data)

    def test_adaptive_reduction_setting_must_be_boolean(self):
        for value in (True, False):
            self.assertIsInstance(value, bool)
        self.assertNotIsInstance("false", bool)

    def test_version_is_timestamp_derived(self):
        updated_at = datetime(2026, 11, 23, 12, 34, 56, tzinfo=timezone.utc)
        version = _threshold_config_version({"updatedAt": updated_at})
        self.assertTrue(version.startswith("thresholds-v"))
        self.assertEqual(version, f"thresholds-v{int(updated_at.timestamp())}")
        self.assertEqual(_threshold_config_version(None), "thresholds-v0")


if __name__ == "__main__":
    unittest.main()
