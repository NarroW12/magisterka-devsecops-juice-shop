#!/usr/bin/env bash
#
# scripts/scenario_b_variant_3_finish.sh <run-number>
#
# Druga połowa scenariusza B wariant 3 (kontrola negatywna). Po zapisaniu
# czterech screenów w docs/screenshots/scenario-b/variant-3/run-<N>/ skrypt
# zamyka PR, kasuje gałąź, wraca na main.

set -euo pipefail

usage() {
  echo "Użycie: $0 <run-number>"
  echo "Przykład: $0 1"
  exit 1
}

[[ "$#" -eq 1 ]] || usage
RUN_N="$1"
[[ "$RUN_N" =~ ^[0-9]+$ ]] || usage

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

BRANCH="scenario-b-variant-3-run-${RUN_N}"
SCREENSHOTS_DIR="docs/screenshots/scenario-b/variant-3/run-${RUN_N}"

echo "============================================================"
echo "SCENARIUSZ B WARIANT 3 RUN ${RUN_N} — FINISH"
echo "============================================================"

echo "[1/4] Weryfikuję screeny w ${SCREENSHOTS_DIR}"
# Inne nazwy niż w wariancie 2 — kontrola negatywna pokazuje PASS, nie BLOCK
EXPECTED=(01-pr-passed.png 02-security-tab.png 03-ci-log.png 04-sarif-detail.png)
MISSING=()
for f in "${EXPECTED[@]}"; do
  if [[ ! -f "${SCREENSHOTS_DIR}/${f}" ]]; then
    MISSING+=("${f}")
  fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "  ⚠ Brakujące screeny:"
  for f in "${MISSING[@]}"; do
    echo "      - ${SCREENSHOTS_DIR}/${f}"
  done
  echo "  Skrypt mimo to dokończy sprzątanie."
else
  echo "  ✓ Wszystkie 4 screeny obecne"
fi

echo "[2/4] Znajduję PR na gałęzi ${BRANCH}"
PR_NUM=$(gh pr list --head "$BRANCH" --state open --json number --jq '.[0].number' 2>/dev/null || true)
if [[ -z "${PR_NUM:-}" ]]; then
  echo "  Brak otwartego PR na ${BRANCH} — pominięto zamykanie."
else
  echo "  PR #${PR_NUM} — zamykam i kasuję gałąź"
  gh pr close "$PR_NUM" \
    --comment "Run ${RUN_N} wariantu 3 (kontrola negatywna) ukończony — komplet dowodów zapisany w docs/screenshots/scenario-b/variant-3/run-${RUN_N}/." \
    --delete-branch
fi

echo "[3/4] Wracam na main"
git checkout main
git pull --prune
git branch -D "$BRANCH" 2>/dev/null || true

echo "[4/4] Stan końcowy"
ls -la "${SCREENSHOTS_DIR}/" 2>/dev/null | grep -E "\.png$" || true

cat <<EOF

============================================================
RUN ${RUN_N} WARIANT 3 (kontrola negatywna) ZAKOŃCZONY
============================================================

Następny run:
  bash scripts/scenario_b_variant_3_start.sh $((RUN_N + 1))

EOF
