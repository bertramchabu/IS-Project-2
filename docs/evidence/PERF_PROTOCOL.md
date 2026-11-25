# NetVision AI Performance Protocol

## Deployed callable benchmark

`benchmark_alert_latency.py --n 100 --url <callable-url>` is the intended
deployment benchmark. It measures wall-clock send-to-`alert_tripped=true`
response latency. It must run with an authenticated Network/System Administrator
identity.

Until a callable URL and authenticated client are available, the script fails
explicitly and generates no fabricated latency result.

## Baseline simulator

`baseline_threshold_sim.py` applies the repository's static threshold rules to
the synthetic held-out KPI CSV at 30-second polling intervals. It is not
wall-clock deployment evidence and must not be reported as real NOC latency.

## Output

- `LATENCY_RESULTS.json`
- `BASELINE_LATENCY_RESULTS.json`
