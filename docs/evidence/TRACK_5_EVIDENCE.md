# Track 5 Evidence - Human and Performance Evidence

## UTC
`2026-11-23`

## Files changed
- `tools/sus/generate_form.py`
- `tools/sus/score.py`
- `tools/sus/responses.template.csv`
- `docs/evidence/SUS_PROTOCOL.md`
- `docs/evidence/SUS_FORM.md`
- `tools/perf/benchmark_alert_latency.py`
- `tools/perf/baseline_threshold_sim.py`
- `docs/evidence/PERF_PROTOCOL.md`
- `docs/evidence/LATENCY_RESULTS.json`
- `docs/evidence/BASELINE_LATENCY_RESULTS.json`
- `.github/workflows/perf.yml`

## Commands

```powershell
python tools/sus/generate_form.py
python tools/sus/score.py tools/sus/responses.template.csv
python tools/perf/baseline_threshold_sim.py --n 100
python tools/perf/benchmark_alert_latency.py --n 100
```

## Raw stdout/stderr

SUS form:

```text
Wrote C:\Users\Bertram Chabu\Videos\github\IS-Project-2\docs\evidence\SUS_FORM.md
```

Empty SUS response template:

```text
No SUS responses found.
```

Baseline threshold simulator:

```text
method=30-second-poll threshold baseline
N=100
timestamp generated 2026-11-23T16:38:20.797258+00:00
dataset=model/data/test_kpi_dataset.csv
caveat=Synthetic row simulation; not wall-clock deployment latency.
```

Deployed latency benchmark:

```text
A deployed callable URL is required; no synthetic latency was generated.
```

## Claims unlocked
- SUS protocol, printable form and strict raw-response scorer exist.
- The response template has no invented participant score.
- Baseline 30-second polling simulation JSON exists.
- Deployed latency benchmark tooling exists and fails explicitly without deployment.
- Weekly performance workflow is declared.

## Claims NOT unlocked
- No real SUS participants or raw SUS responses exist.
- No 83.5 SUS claim is newly validated.
- No deployed p50/p95/p99 latency exists.
- No 1.25-second or 31.4-second wall-clock field evidence exists.
