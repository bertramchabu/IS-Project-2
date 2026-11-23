import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def validate() -> list[str]:
    devices = json.loads((ROOT / "assets/simulation/devices.json").read_text())["devices"]
    topology = json.loads((ROOT / "assets/simulation/topology.json").read_text())
    errors = []
    types = {}
    for device in devices:
        types.setdefault(device["type"], []).append(device)

    if len([d for d in devices if d["type"] == "core_router"]) != 2:
        errors.append("HQ requires exactly 2 core_router devices.")
    if len([d for d in devices if d["type"] == "firewall" and d["siteId"] == "hq"]) != 2:
        errors.append("HQ requires exactly 2 firewalls.")
    if len([d for d in devices if d["type"] == "core_switch" and d["siteId"] == "hq"]) != 4:
        errors.append("HQ requires exactly 4 core_switches.")
    if len([d for d in devices if d["type"] == "isp_uplink" and d["siteId"] == "hq"]) != 2:
        errors.append("HQ requires exactly 2 ISP uplinks.")
    if len(devices) != 42:
        errors.append(f"Enterprise inventory must contain 42 devices; found {len(devices)}.")

    for link in topology["links"]:
        ids = {device["id"] for device in devices}
        if link["from"] not in ids or link["to"] not in ids:
            errors.append(f"Topology link {link['id']} references an unknown device.")
    return errors


if __name__ == "__main__":
    problems = validate()
    if problems:
        print("\n".join(problems), file=sys.stderr)
        raise SystemExit(1)
    print("Topology validation passed.")
