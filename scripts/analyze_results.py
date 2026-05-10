"""Parser SARIF → CSV dla wyników eksperymentu.

Skrypt iteruje po katalogu `data/raw/` w poszukiwaniu plików `*.sarif`,
parsuje je do jednolitego formatu i zapisuje skonsolidowany CSV pod
`data/results.csv`. Klasyfikacja True Positive / False Positive jest
domyślnie pusta — uzupełniana ręcznie na podstawie znanej listy
wprowadzonych podatności w danym scenariuszu.

Uruchomienie:
    python scripts/analyze_results.py

TODO: implementacja zostanie uzupełniona po wykonaniu pierwszych przebiegów,
gdy będzie dostępny realny zestaw plików SARIF do walidacji parsera.
"""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "data" / "raw"
OUTPUT = ROOT / "data" / "results.csv"

CSV_FIELDS = [
    "scenario",
    "run",
    "tool",
    "rule_id",
    "rule_name",
    "severity",
    "file",
    "line",
    "message",
    "classification",  # TP / FP / unknown
]


def parse_sarif(path: Path) -> list[dict]:
    """Convert a single SARIF file into a list of finding dicts."""
    try:
        sarif = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"[WARN] Skipping malformed SARIF: {path} ({exc})", file=sys.stderr)
        return []

    findings: list[dict] = []
    for run in sarif.get("runs", []):
        tool_name = (
            run.get("tool", {}).get("driver", {}).get("name", "unknown")
        )
        for result in run.get("results", []):
            location = (
                result.get("locations", [{}])[0]
                .get("physicalLocation", {})
            )
            findings.append(
                {
                    "tool": tool_name,
                    "rule_id": result.get("ruleId", ""),
                    "rule_name": result.get("message", {}).get(
                        "text", ""
                    )[:80],
                    "severity": result.get("level", "note"),
                    "file": location.get("artifactLocation", {}).get(
                        "uri", ""
                    ),
                    "line": location.get("region", {}).get("startLine", ""),
                    "message": result.get("message", {}).get("text", ""),
                    "classification": "unknown",
                }
            )
    return findings


def main() -> int:
    if not RAW_DIR.exists():
        print(f"[ERROR] Raw data directory not found: {RAW_DIR}", file=sys.stderr)
        return 1

    rows: list[dict] = []
    for sarif_path in sorted(RAW_DIR.rglob("*.sarif")):
        # Path layout: data/raw/<scenario>/<run>/...
        try:
            relative = sarif_path.relative_to(RAW_DIR)
            scenario = relative.parts[0]
            run = relative.parts[1] if len(relative.parts) > 1 else "unknown"
        except (IndexError, ValueError):
            scenario, run = "unknown", "unknown"

        for finding in parse_sarif(sarif_path):
            finding["scenario"] = scenario
            finding["run"] = run
            rows.append(finding)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {len(rows)} findings to {OUTPUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
