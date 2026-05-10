"""Skrypt zbierający czasy wykonania workflow GitHub Actions.

Wykorzystuje GitHub CLI (`gh run list --json ...`) do pobrania metadanych
ostatnich uruchomień workflow oraz zapisuje je do pliku CSV stanowiącego
wejście do obliczenia metryki Build Time Impact (BTI) w rozdziale 5.

Uruchomienie:
    python scripts/timing_report.py --workflow security-pipeline.yml --limit 50

TODO: implementacja zostanie uzupełniona po pierwszym zielonym przebiegu
workflow CI, gdy będzie dostępny realny zbiór run-ów do parsowania.
"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "data" / "timings.csv"


def fetch_runs(workflow: str, limit: int) -> list[dict]:
    cmd = [
        "gh",
        "run",
        "list",
        "--workflow",
        workflow,
        "--limit",
        str(limit),
        "--json",
        "databaseId,headBranch,event,status,conclusion,createdAt,updatedAt,name",
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        print(f"[ERROR] gh CLI failed: {proc.stderr}", file=sys.stderr)
        return []
    return json.loads(proc.stdout)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workflow", default="security-pipeline.yml")
    parser.add_argument("--limit", type=int, default=50)
    args = parser.parse_args()

    runs = fetch_runs(args.workflow, args.limit)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    fields = [
        "run_id",
        "branch",
        "event",
        "status",
        "conclusion",
        "created_at",
        "updated_at",
        "duration_seconds",
    ]
    from datetime import datetime

    with OUTPUT.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        for run in runs:
            created = datetime.fromisoformat(
                run["createdAt"].replace("Z", "+00:00")
            )
            updated = datetime.fromisoformat(
                run["updatedAt"].replace("Z", "+00:00")
            )
            writer.writerow(
                {
                    "run_id": run["databaseId"],
                    "branch": run["headBranch"],
                    "event": run["event"],
                    "status": run["status"],
                    "conclusion": run["conclusion"],
                    "created_at": run["createdAt"],
                    "updated_at": run["updatedAt"],
                    "duration_seconds": int(
                        (updated - created).total_seconds()
                    ),
                }
            )

    print(f"Wrote {len(runs)} run records to {OUTPUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
