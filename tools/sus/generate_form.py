"""Generate a printable NetVision SUS and consent brief."""

from pathlib import Path


OUTPUT = Path(__file__).resolve().parents[2] / "docs/evidence/SUS_FORM.md"

ITEMS = [
    "I think that I would like to use NetVision AI frequently.",
    "I found NetVision AI unnecessarily complex.",
    "I thought NetVision AI was easy to use.",
    "I think that I would need the support of a technical person to use NetVision AI.",
    "I found the various functions in NetVision AI were well integrated.",
    "I thought there was too much inconsistency in NetVision AI.",
    "I would imagine that most people would learn to use NetVision AI very quickly.",
    "I found NetVision AI very cumbersome to use.",
    "I felt very confident using NetVision AI.",
    "I needed to learn a lot of things before I could get going with NetVision AI.",
]


def main() -> int:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# NetVision AI SUS Form",
        "",
        "Participant ID: __________",
        "Date: __________",
        "",
        "Consent: I consent to anonymous SUS data being used for academic evaluation.",
        "Signature: __________",
        "",
        "Rate each statement from 1 (Strongly disagree) to 5 (Strongly agree).",
        "",
    ]
    for index, item in enumerate(ITEMS, 1):
        lines.append(f"{index}. {item}")
        lines.append("   1  2  3  4  5")
        lines.append("")
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
