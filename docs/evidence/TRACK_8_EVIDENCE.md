# Track 8 Evidence - Final QA Gate

## UTC
`2026-11-23`

## Command log

```powershell
git --no-pager status --short
git --no-pager log -8 --format="%h %cI %s"
flutter test --reporter expanded
flutter analyze
Set-Location model
& '.\.venv\Scripts\python.exe' -m unittest discover -s tests -v
flutter build web --release
flutter build apk --release
python tools/validate_topology.py
python tools/perf/baseline_threshold_sim.py --n 100
python -m src.retrain_runner --dry-run --request-id track8-evidence
```

## Pass counts

- Flutter full suite: 46 tests passed.
- Flutter targeted Track 1/2/6 suite: 5 tests passed.
- Python full suite: 26 tests passed.
- Topology validator: passed.
- Retraining runner dry-run: passed.
- Baseline threshold simulator: passed.
- Web release build: passed.

## Analyzer

`flutter analyze` remains non-zero with 59 issues. This QA gate therefore does
not claim 0 analyzer issues.

## Web build hashes

- `build/web/main.dart.js`:
  `EB6F67D16DC0A7D6FB8B73368FF1A54C619EE9970073745BF271517A5E59D4F6`
- `build/web/flutter_bootstrap.js`:
  `2F4A20BBB3F6598BA19F1DCE92047F5FFE7303D4645C1D47A5DDD73CBB8C0F7B`

## APK build

The `flutter build apk --release` command was started and remained in the Gradle
`assembleRelease` task for more than 15 minutes. It was stopped and no APK success
was claimed.

## Ledger mapping

| Claim | Evidence |
|---|---|
| Model A metrics | `METRICS_LEDGER.md`, `model/results/evaluation_report.json` |
| Model B metrics | `METRICS_LEDGER.md`, threat evaluation JSON |
| Runtime thresholds | Track 1 evidence |
| Retraining dry-run | Track 2 evidence |
| Collector loopback 90 samples | Track 3 evidence |
| Enterprise 42-device topology | Track 4 evidence |
| SUS protocol/form | Track 5 evidence |
| Baseline threshold simulation | Track 5 evidence |
| Unknown-role and CORS hardening | Track 6 evidence |
| Separate model diagrams | Track 7 evidence |

## Remaining honest limitations

- No raw SUS responses or participant IDs.
- No deployed p50/p95/p99 latency JSON.
- No real production telemetry dataset or incident ground truth.
- No real Firebase retraining execution.
- No deployed emulator rules-test execution.
- No real Firebase MFA enrollment/enforcement.
- No deployed Firestore collector verification.
- APK release build did not complete in this turn.
- Final analyzer is not green.
- DOCX and PNG regeneration remain incomplete.

No `v1.0.0-final-doc` tag was created.
