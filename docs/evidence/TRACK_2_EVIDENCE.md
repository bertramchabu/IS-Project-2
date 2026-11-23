# Track 2 Evidence - Retraining Pipeline

## UTC
`2026-11-23`

## Files changed
- `model/src/retrain_runner.py` - real train/evaluate subprocess runner plus `--dry-run`.
- `model/src/train.py` - accepts `--dataset`.
- `model/main.py` - adds system-admin `process_retrain_request` callable.
- `.github/workflows/retrain.yml` - workflow_dispatch entry point.
- `lib/presentation/dashboard/pages/system_admin_home.dart` - live latest-retrain status banner.
- `model/tests/test_retrain_pipeline.py` - state transitions, hashing and 4KB capture checks.
- `test/retrain_status_test.dart` - Flutter status mapping tests.
- `docs/NetVision_AI_Application_Documentation.md` - model-management and limitations update.

## State transitions
1. Pending request in `retrainRequests/{id}`.
2. Callable marks `status=in_progress`, `startedAt`, `startedBy`.
3. Runner executes `src.train --dataset <path>` and `src.evaluate`.
4. On success: `completed`, `completedAt`, F1, RMSE, artifact SHA-256 values and subdocument evaluation report.
5. On failure: `failed`, `failedAt`, and stderr truncated to 4096 characters.

## Dry-run command

```powershell
Set-Location 'C:\Users\Bertram Chabu\Videos\github\IS-Project-2\model'
& '.\.venv\Scripts\python.exe' -m src.retrain_runner --dry-run --request-id track2-evidence
```

Raw stdout:

```json
{
  "dry_run": true,
  "hashes": {
    "dry-run": "not-computed"
  },
  "request_id": "dry-run-request",
  "transitions": [
    {
      "request_id": "dry-run-request",
      "status": "in_progress"
    },
    {
      "request_id": "dry-run-request",
      "status": "completed",
      "stub": true
    }
  ]
}
```

## Python tests

```powershell
Set-Location 'C:\Users\Bertram Chabu\Videos\github\IS-Project-2\model'
& '.\.venv\Scripts\python.exe' -m unittest discover -s tests -p 'test_retrain_pipeline.py' -v
```

Raw stdout:

```text
test_dry_run_exercises_state_transitions (test_retrain_pipeline.RetrainPipelineTests.test_dry_run_exercises_state_transitions) ... ok
test_failure_capture_is_truncated_and_hashing_is_stable (test_retrain_pipeline.RetrainPipelineTests.test_failure_capture_is_truncated_and_hashing_is_stable) ... ok

----------------------------------------------------------------------
Ran 2 tests in 0.018s

OK
```

## Dart tests

```powershell
flutter test test/retrain_status_test.dart --reporter expanded
```

Raw stdout:

```text
00:00 +0: loading C:/Users/Bertram Chabu/Videos/github/IS-Project-2/test/retrain_status_test.dart
00:00 +0: maps queued and in-progress request states
00:00 +1: maps completed metrics and failed errors
00:00 +2: All tests passed!
```

## Claims unlocked
- A callable and runner implement retraining state transitions.
- A `--dry-run` mode exercises queued-to-in-progress-to-completed state mapping.
- SHA-256 helper and 4096-character failure capture have unit coverage.
- The UI has a live latest-request status banner.
- A workflow_dispatch workflow is declared.

## Claims NOT unlocked
- No full real training run was executed.
- No Firebase `retrainRequests` document was transitioned in a deployed project.
- No service account workflow secret was verified.
- The pipeline closes the queue-only stub in code but remains runtime-dependent.
