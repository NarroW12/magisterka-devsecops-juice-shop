"""Parser SARIF/ZAP -> data/results.csv (summary) + data/findings.csv (detail).

Iteruje po data/raw/ rozpoznając dwa układy ścieżek:
  - data/raw/<scenario>/run-<N>/...                  (faza 1, variant=1)
  - data/raw/<scenario>/variant-<V>/run-<N>/...      (faza 2)

Z lokalnych artefaktów (Gitleaks, Dependency-Check, ZAP) liczy znaleziska
w kubełkach severity. Trivy/Hadolint/Checkov nie są tu parsowane bo w fazie 1
nie były archiwizowane lokalnie (wgrywane tylko do GitHub Advanced Security).
Dla fazy 2 należy rozszerzyć workflow o upload-artifact dla tych narzędzi.

Uruchomienie:
    python scripts/analyze_results.py
"""

from __future__ import annotations

import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "data" / "raw"
RESULTS_CSV = ROOT / "data" / "results.csv"
FINDINGS_CSV = ROOT / "data" / "findings.csv"

SEV_BUCKETS = ("critical", "high", "medium", "low", "info")

SUMMARY_FIELDS = [
    "scenario",
    "variant",
    "run",
    "gitleaks_findings",
    "depcheck_critical",
    "depcheck_high",
    "depcheck_medium",
    "depcheck_low",
    "zap_high",
    "zap_medium",
    "zap_low",
    "zap_info",
    "gate_blocked_expected",
]

FINDING_FIELDS = [
    "scenario",
    "variant",
    "run",
    "tool",
    "rule_id",
    "severity",
    "cvss",
    "file",
    "line",
    "message",
]


def parse_path(rel: Path) -> tuple[str, int, int] | None:
    """Map a relative path under data/raw/ to (scenario, variant, run).

    Recognised layouts:
        scenario-x/run-N/...                -> (scenario-x, 1, N)
        scenario-x/variant-V/run-N/...      -> (scenario-x, V, N)
    """
    parts = rel.parts
    if len(parts) < 2:
        return None
    scenario = parts[0]
    if not scenario.startswith("scenario-"):
        return None

    run_match = re.match(r"run-(\d+)$", parts[1])
    if run_match:
        return scenario, 1, int(run_match.group(1))

    var_match = re.match(r"variant-(\d+)$", parts[1])
    if var_match and len(parts) >= 3:
        run_match = re.match(r"run-(\d+)$", parts[2])
        if run_match:
            return scenario, int(var_match.group(1)), int(run_match.group(1))
    return None


def discover_runs() -> dict[tuple[str, int, int], Path]:
    """Find every run directory under data/raw/. Return key -> run-dir mapping."""
    runs: dict[tuple[str, int, int], Path] = {}
    if not RAW_DIR.exists():
        return runs

    for scenario_dir in sorted(RAW_DIR.iterdir()):
        if not scenario_dir.is_dir() or not scenario_dir.name.startswith("scenario-"):
            continue
        # variant-* directories OR direct run-* directories
        for sub in sorted(scenario_dir.iterdir()):
            if not sub.is_dir():
                continue
            if re.match(r"run-\d+$", sub.name):
                key = parse_path(sub.relative_to(RAW_DIR))
                if key:
                    runs[key] = sub
            elif re.match(r"variant-\d+$", sub.name):
                for run_dir in sorted(sub.iterdir()):
                    if run_dir.is_dir() and re.match(r"run-\d+$", run_dir.name):
                        key = parse_path(run_dir.relative_to(RAW_DIR))
                        if key:
                            runs[key] = run_dir
    return runs


def _build_rule_index(sarif_run: dict) -> dict[str, dict]:
    """Map ruleId -> rule definition (for tools that put severity in rules)."""
    return {
        rule.get("id", ""): rule
        for rule in sarif_run.get("tool", {}).get("driver", {}).get("rules", [])
        if rule.get("id")
    }


def _depcheck_severity(rule: dict | None, result_level: str) -> str:
    """Pick CRITICAL/HIGH/MEDIUM/LOW for Dep-Check finding.

    Prefers cvssv3_baseSeverity from the rule, falls back to SARIF level.
    """
    if rule:
        props = rule.get("properties", {})
        sev = (props.get("cvssv3_baseSeverity") or "").upper()
        if sev in {"CRITICAL", "HIGH", "MEDIUM", "LOW"}:
            return sev.lower()
    # SARIF level -> rough mapping
    return {"error": "high", "warning": "medium", "note": "low"}.get(
        result_level, "low"
    )


def _depcheck_cvss(rule: dict | None) -> float | None:
    if not rule:
        return None
    props = rule.get("properties", {})
    val = props.get("cvssv3_baseScore") or props.get("security-severity")
    try:
        return float(val) if val is not None else None
    except (TypeError, ValueError):
        return None


def parse_gitleaks(sarif_path: Path) -> list[dict]:
    """Each finding has implicit severity=critical (any secret blocks)."""
    try:
        data = json.loads(sarif_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as exc:
        print(f"[WARN] Bad gitleaks SARIF {sarif_path}: {exc}", file=sys.stderr)
        return []

    findings = []
    for run in data.get("runs", []):
        for r in run.get("results", []):
            loc = r.get("locations", [{}])[0].get("physicalLocation", {})
            findings.append(
                {
                    "tool": "gitleaks",
                    "rule_id": r.get("ruleId", ""),
                    "severity": "critical",
                    "cvss": "",
                    "file": loc.get("artifactLocation", {}).get("uri", ""),
                    "line": loc.get("region", {}).get("startLine", ""),
                    "message": (r.get("message", {}).get("text", "") or "")[:160],
                }
            )
    return findings


def parse_depcheck(sarif_path: Path) -> list[dict]:
    try:
        data = json.loads(sarif_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as exc:
        print(f"[WARN] Bad dep-check SARIF {sarif_path}: {exc}", file=sys.stderr)
        return []

    findings = []
    for run in data.get("runs", []):
        rules = _build_rule_index(run)
        for r in run.get("results", []):
            rule_id = r.get("ruleId", "")
            rule = rules.get(rule_id)
            loc = r.get("locations", [{}])[0].get("physicalLocation", {})
            findings.append(
                {
                    "tool": "dependency-check",
                    "rule_id": rule_id,
                    "severity": _depcheck_severity(rule, r.get("level", "")),
                    "cvss": _depcheck_cvss(rule) or "",
                    "file": loc.get("artifactLocation", {}).get("uri", ""),
                    "line": loc.get("region", {}).get("startLine", ""),
                    "message": (r.get("message", {}).get("text", "") or "")[:160],
                }
            )
    return findings


_ZAP_RISK_MAP = {0: "info", 1: "low", 2: "medium", 3: "high"}


def parse_zap(json_path: Path) -> list[dict]:
    """ZAP JSON: aggregate alerts; expand by `count` instances per alert."""
    try:
        data = json.loads(json_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as exc:
        print(f"[WARN] Bad ZAP JSON {json_path}: {exc}", file=sys.stderr)
        return []

    findings = []
    for site in data.get("site", []):
        site_uri = site.get("@name", "")
        for alert in site.get("alerts", []):
            risk_code = int(alert.get("riskcode", 0))
            severity = _ZAP_RISK_MAP.get(risk_code, "info")
            count = int(alert.get("count", 1))
            findings.append(
                {
                    "tool": "zap",
                    "rule_id": alert.get("pluginid", ""),
                    "severity": severity,
                    "cvss": "",
                    "file": site_uri,
                    "line": count,  # liczba instancji
                    "message": (alert.get("alert", "") or "")[:160],
                }
            )
    return findings


def collect_run(run_dir: Path) -> list[dict]:
    """Parse all known artefacts in a single run directory."""
    findings: list[dict] = []

    for gl in run_dir.rglob("gitleaks.sarif"):
        findings.extend(parse_gitleaks(gl))
    for dc in run_dir.rglob("dependency-check-report.sarif"):
        findings.extend(parse_depcheck(dc))
    for zp in run_dir.rglob("report_json.json"):
        # Tylko jeśli ścieżka zawiera "zap" — uniknij przypadkowych kolizji.
        if "zap" in str(zp).lower():
            findings.extend(parse_zap(zp))
    return findings


def summarise(scenario: str, variant: int, run: int, findings: list[dict]) -> dict:
    by_tool_sev: dict[tuple[str, str], int] = defaultdict(int)
    for f in findings:
        by_tool_sev[(f["tool"], f["severity"])] += 1

    gitleaks_total = sum(c for (t, _), c in by_tool_sev.items() if t == "gitleaks")
    dc = {sev: by_tool_sev.get(("dependency-check", sev), 0) for sev in SEV_BUCKETS}
    zap = {sev: by_tool_sev.get(("zap", sev), 0) for sev in SEV_BUCKETS}

    # Wstępna heurystyka bramki: Gitleaks > 0 LUB Dep-Check CRITICAL > 0 LUB ZAP High > 0.
    # Faktyczne PASS/FAIL bramki workflow trzeba doczytać z gh API w osobnym kroku.
    gate_blocked = (
        gitleaks_total > 0
        or dc["critical"] > 0
        or zap["high"] > 0
    )

    return {
        "scenario": scenario,
        "variant": variant,
        "run": run,
        "gitleaks_findings": gitleaks_total,
        "depcheck_critical": dc["critical"],
        "depcheck_high": dc["high"],
        "depcheck_medium": dc["medium"],
        "depcheck_low": dc["low"],
        "zap_high": zap["high"],
        "zap_medium": zap["medium"],
        "zap_low": zap["low"],
        "zap_info": zap["info"],
        "gate_blocked_expected": int(gate_blocked),
    }


def main() -> int:
    if not RAW_DIR.exists():
        print(f"[ERROR] Raw data directory not found: {RAW_DIR}", file=sys.stderr)
        return 1

    runs = discover_runs()
    if not runs:
        print(f"[ERROR] No runs found under {RAW_DIR}", file=sys.stderr)
        return 1

    print(f"Discovered {len(runs)} run directories")

    summary_rows: list[dict] = []
    detail_rows: list[dict] = []

    for (scenario, variant, run), run_dir in sorted(runs.items()):
        findings = collect_run(run_dir)
        summary_rows.append(summarise(scenario, variant, run, findings))
        for f in findings:
            detail_rows.append(
                {
                    "scenario": scenario,
                    "variant": variant,
                    "run": run,
                    **f,
                }
            )

    RESULTS_CSV.parent.mkdir(parents=True, exist_ok=True)
    with RESULTS_CSV.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=SUMMARY_FIELDS)
        writer.writeheader()
        writer.writerows(summary_rows)
    print(f"Wrote {len(summary_rows)} summary rows to {RESULTS_CSV}")

    with FINDINGS_CSV.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=FINDING_FIELDS)
        writer.writeheader()
        writer.writerows(detail_rows)
    print(f"Wrote {len(detail_rows)} detail rows to {FINDINGS_CSV}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
