# Track 1 Evidence - Runtime Threshold Enforcement

## Freeze
- Track 0 commit: `767c193`
- UTC: `2026-11-23`

## Files changed
- `model/main.py` - added threshold cache/loading, bounds validation, version stamping, `get_thresholds` and `set_thresholds`.
- `lib/core/utils/threshold_validation.dart` - mirrors server numeric bounds for inline UI validation.
- `lib/presentation/dashboard/pages/system_admin_home.dart` - loads effective callable values and writes through `set_thresholds`.
- `model/tests/test_thresholds.py` - validates bounds, fallback data and version derivation.
- `test/threshold_config_test.dart` - validates Dart-side mirrored bounds.
- `docs/NetVision_AI_Application_Documentation.md` - replaces the runtime hard-coded limitation with runtime configuration behaviour.
- `docs/evidence/TRACK_1_EVIDENCE.md` - records evidence and runtime boundaries.

## Before

The baseline implementation used constants:

```python
ALERT_THRESHOLD = 0.70
WARNING_THRESHOLD = 0.30
HEALTHY_SAMPLING_INTERVAL_SEC = 10.0
THRESHOLD_CONFIG_VERSION = "fault-thresholds-v1"
```

`predict_fault` used those constants and did not read `systemConfig/thresholds`.

## After

`predict_fault` now executes:

```python
threshold_config, threshold_config_version = _load_thresholds()
alert_threshold = threshold_config["globalThreshold"]
warning_threshold = threshold_config["reductionThreshold"]
healthy_sampling_interval = threshold_config["healthyInterval"]
reduction_percentage = threshold_config["reductionPercentage"]
```

Every response includes `thresholdConfigVersion`, derived as:

```python
f"thresholds-v{int(updatedAt.timestamp())}"
```

Missing or malformed configuration falls back to:

```python
globalThreshold = 0.70
reductionThreshold = 0.30
reductionPercentage = 90
healthyInterval = 10.0
```

## Server bounds

- `0.5 <= globalThreshold <= 0.95`
- `0.1 <= reductionThreshold < globalThreshold`
- `50 <= reductionPercentage <= 95`
- `1 <= healthyInterval <= 60`

Invalid documents fall back, while `set_thresholds` rejects invalid request values with `INVALID_ARGUMENT`.

## Commands

```powershell
Set-Location 'C:\Users\Bertram Chabu\Videos\github\IS-Project-2\model'
& '.\.venv\Scripts\python.exe' -m unittest discover -s tests -p 'test_thresholds.py' -v

Set-Location 'C:\Users\Bertram Chabu\Videos\github\IS-Project-2'
flutter test test/threshold_config_test.dart --reporter expanded

dart format --output=none --set-exit-if-changed lib/core/utils/threshold_validation.dart lib/presentation/dashboard/pages/system_admin_home.dart test/threshold_config_test.dart
```

## Raw stdout/stderr

Python threshold tests:

```text
test_accepts_bounds_and_defaults (test_thresholds.ThresholdValidationTests.test_accepts_bounds_and_defaults) ... ok
test_adaptive_reduction_setting_must_be_boolean (test_thresholds.ThresholdValidationTests.test_adaptive_reduction_setting_must_be_boolean) ... ok
test_rejects_out_of_bounds_values (test_thresholds.ThresholdValidationTests.test_rejects_out_of_bounds_values) ... ok
test_version_is_timestamp_derived (test_thresholds.ThresholdValidationTests.test_version_is_timestamp_derived) ... ok

----------------------------------------------------------------------
Ran 4 tests in 0.001s

OK
```

Full Python suite:

```text
Ran 18 tests in 3.875s

OK
```

Dart threshold tests:

```text
00:00 +0: loading C:/Users/Bertram Chabu/Videos/github/IS-Project-2/test/threshold_config_test.dart
00:00 +0: accepts valid threshold policy values
00:00 +1: mirrors server bounds
00:00 +2: All tests passed!
```

Dart format result:

```text
Changed lib/core/utils/threshold_validation.dart
Formatted 3 files (1 changed) in 0.14 seconds.
```

## Before/after payload shape

Before:

```json
{
  "thresholdConfigVersion": "fault-thresholds-v1",
  "thresholds": {
    "warning": 0.30,
    "alert": 0.70
  }
}
```

After:

```json
{
  "thresholdConfigVersion": "thresholds-v<updatedAtUnix>",
  "thresholds": {
    "warning": "<configured reductionThreshold>",
    "alert": "<configured globalThreshold>"
  },
  "next_sampling_interval_sec": "<configured healthyInterval or 1.0>",
  "computational_savings_percent": "<configured reductionPercentage or 0>"
}
```

## Runtime verification boundary

- Unit tests verify validation and version derivation.
- Source verification confirms `predict_fault` reads effective thresholds.
- A real before/after Firestore payload comparison was NOT executed because no deployed callable credentials/session is available in this turn.
- Therefore this track closes the implemented gap but does **not** claim production deployment verification.

## Claims unlocked
- Runtime threshold loading is implemented in `predict_fault`.
- Effective values have a timestamp-derived version.
- `get_thresholds` and `set_thresholds` are system-admin callable paths.
- UI loads effective values and mirrors server bounds.
- Out-of-bounds threshold writes are rejected with structured validation.

## Claims NOT unlocked
- Deployed Firebase behavior was not exercised.
- Firestore emulator behavior was not exercised.
- Firestore rules for threshold writes remain outside this track.
- Retraining, telemetry, SUS, latency, MFA, unknown-role and production threat gaps remain open.
