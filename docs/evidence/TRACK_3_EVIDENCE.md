# Track 3 Evidence - Production Telemetry Collector

## UTC
`2026-11-23`

## Files changed
- `model/collector/agent.py` - TCP latency/jitter/loss collector with dry-run and Firebase/emulator write branches.
- `model/collector/config.example.yml` - three loopback synthetic targets.
- `model/tests/test_collector.py` - probe math, missing key, dry-run and config tests.
- `.github/workflows/collector-smoke.yml` - loopback container smoke workflow.
- `lib/presentation/dashboard/pages/system_admin_home.dart` - collector command and copy button.
- `docs/NetVision_AI_Application_Documentation.md` - collector implementation section and honest limitation.

## Commands

```powershell
Set-Location 'C:\Users\Bertram Chabu\Videos\github\IS-Project-2'
& 'C:\Users\Bertram Chabu\Videos\github\IS-Project-2\model\.venv\Scripts\python.exe' -m http.server 18080 --bind 127.0.0.1

Set-Location 'C:\Users\Bertram Chabu\Videos\github\IS-Project-2\model'
& '.\.venv\Scripts\python.exe' collector/agent.py --dry-run --config collector/config.example.yml --count 30

& '.\.venv\Scripts\python.exe' -m unittest discover -s tests -p 'test_collector.py' -v
& '.\.venv\Scripts\python.exe' -m py_compile collector/agent.py
```

## Raw stdout/stderr

Python tests:

```text
test_dry_run_does_not_require_key (test_collector.CollectorTests.test_dry_run_does_not_require_key) ... ok
test_missing_key_requires_service_account_or_emulator (test_collector.CollectorTests.test_missing_key_requires_service_account_or_emulator) ... ok
test_probe_math_and_packet_loss (test_collector.CollectorTests.test_probe_math_and_packet_loss) ... ok
test_yaml_config_loader (test_collector.CollectorTests.test_yaml_config_loader) ... ok

----------------------------------------------------------------------
Ran 4 tests in 0.007s

OK
```

Loopback dry-run summary:

```json
{"dry_run": true, "samples": 90}
```

The run emitted 30 samples for each of:

- `SYNTHETIC-DEMO-NODE`
- `SYNTHETIC-DEMO-NODE-2`
- `SYNTHETIC-DEMO-NODE-3`

Each sample contains `latency`, `jitter`, `packet_loss`, `retransmission_rate`,
`signal_strength`, `source=collector`, UTC timestamp and node ID.

Initial loopback attempt:

```text
RuntimeError: No successful TCP probes for localhost:80.
```

This was an example-config issue: no service was listening on port 80. The
configuration was corrected to 127.0.0.1:18080 and rerun successfully.

## Writes

Real mode writes:

- `networkNodes/{nodeId}/kpiMetrics/{metricId}-latency`
- `networkNodes/{nodeId}/kpiMetrics/{metricId}-jitter`
- `networkNodes/{nodeId}/kpiMetrics/{metricId}-packetLoss`
- `networkNodes/{nodeId}/kpiMetrics/{metricId}-retransmissionRate`
- optional `networkNodes/{nodeId}/kpiMetrics/{metricId}-signalStrength`

The write branch requires a service account key or emulator environment. No real
Firebase credentials were available during this track.

## Claims unlocked
- A working dry-run TCP collector produces loopback samples.
- Missing credentials are rejected for real writes.
- Unit tests cover probe math, key refusal and YAML loading.
- System Admin UI provides an exact copyable dry-run command.
- CI declares a loopback smoke workflow.

## Claims NOT unlocked
- No deployed Firestore write was verified.
- No real network service was measured.
- No real incident dataset or ground truth was produced.
- The collector is an on-ramp, not production telemetry evidence.
