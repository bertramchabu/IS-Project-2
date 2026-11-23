"""Print or document the Savannah Retail Group enterprise seed command."""

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    organisation = json.loads(
        (ROOT / "assets/simulation/organisation.json").read_text(encoding="utf-8")
    )
    devices = json.loads(
        (ROOT / "assets/simulation/devices.json").read_text(encoding="utf-8")
    )
    output = {
        "simulationOnly": True,
        "organisation": organisation["name"],
        "deviceCount": len(devices["devices"]),
        "dryRun": args.dry_run,
        "seedCommand": "python tools/seed_enterprise_demo.py --dry-run",
    }
    print(json.dumps(output, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
