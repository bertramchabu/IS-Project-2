# Track 4 Evidence - Enterprise Simulation Environment

## UTC
`2026-11-23`

## Files changed
- `assets/simulation/organisation.json`
- `assets/simulation/devices.json`
- `assets/simulation/topology.json`
- `assets/simulation/scenarios.json`
- `tools/validate_topology.py`
- `model/simulation/enterprise_sim.py`
- `tools/seed_enterprise_demo.py`
- `pubspec.yaml`

## Raw commands and output

```text
python tools/validate_topology.py
Topology validation passed.

python -c "import json; d=json.load(open('assets/simulation/devices.json')); print(len(d['devices']))"
42

python tools/seed_enterprise_demo.py --dry-run
{
  "deviceCount": 42,
  "dryRun": true,
  "organisation": "Savannah Retail Group",
  "seedCommand": "python tools/seed_enterprise_demo.py --dry-run",
  "simulationOnly": true
}
```

Deterministic scenario dry-run:

```text
python model/simulation/enterprise_sim.py --scenario ddos_availability_anomaly --duration 300 --seed 166458 --dry-run
dry_run=true
scenario=ddos_availability_anomaly
rows=300
```

## Claims unlocked
- Named fictional Savannah Retail Group organisation is represented.
- 42-device inventory and topology JSON exist.
- Topology HQ/core/firewall/switch/ISP constraints pass.
- Seven scenario names are defined.
- Deterministic seed 166458 replay produces UTC-second synthetic rows.

## Claims NOT unlocked
- Full 24-branch per-device endpoint inventory is not implemented; the 42-device inventory is a core/representative topology.
- No new NOC topology widget or role Enterprise Overview page was added.
- No real Firestore seed was executed.
- No screenshots or 60-second scenario recording exist.
- Full device-detail, theme toggle and animated packet-flow UI are not implemented.
