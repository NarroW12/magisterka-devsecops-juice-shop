#!/usr/bin/env bash
#
# scripts/scenario_d_start.sh <run-number>
#
# Scenariusz D — dynamiczne testowanie aplikacji (DAST) OWASP ZAP na
# OWASP Juice Shop. W odróżnieniu od scenariuszy A/B/C scenariusz D nie
# wprowadza żadnych podatności — Juice Shop sam z siebie zawiera kilkadziesiąt
# udokumentowanych podatności. Skrypt tworzy gałąź z trywialnym plikiem
# trigger, aby workflow CI uruchomił pełen przebieg (włącznie z Etapem 5 DAST).
#
# Bramka ZAP w workflow jest informacyjna (fail_action: false), więc cały
# workflow zwraca SUCCESS. Mierzymy POJEMNOŚĆ ZAP: liczbę alertów PASS,
# WARN-NEW oraz FAIL-NEW.

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

BRANCH="scenario-d-run-${RUN_N}"
SCREENSHOTS_DIR="docs/screenshots/scenario-d/run-${RUN_N}"
SARIF_DIR="data/raw/scenario-d/run-${RUN_N}"

echo "============================================================"
echo "SCENARIUSZ D RUN ${RUN_N} — START"
echo "  DAST OWASP ZAP na OWASP Juice Shop (informacyjne)"
echo "============================================================"

echo "[1/8] Przełączam się na main i pulluję"
git checkout main
git pull --prune

echo "[2/8] Tworzę gałąź $BRANCH"
git checkout -b "$BRANCH"

echo "[3/8] Tworzę trywialny plik trigger uruchamiający workflow"
mkdir -p docs/scenario-d-triggers
cat > "docs/scenario-d-triggers/run-${RUN_N}.md" <<EOF
# Scenariusz D — run ${RUN_N}

Plik trigger uruchamiający pełen workflow CI dla scenariusza D
(DAST OWASP ZAP na OWASP Juice Shop). Nie wprowadza żadnych podatności
do aplikacji testowej — celem scenariusza jest pomiar pojemności ZAP
w wykrywaniu podatności obecnych w deterministycznej aplikacji testowej.

Run number: ${RUN_N}
Triggered: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
git add "docs/scenario-d-triggers/run-${RUN_N}.md"

echo "[4/8] Commit"
git -c user.email='jakub.omie@gmail.com' -c user.name='NarroW12' \
  commit -m "scenario D run ${RUN_N}: trigger workflow for DAST evaluation"

echo "[5/8] Push origin/$BRANCH"
git push -u origin "$BRANCH"

echo "[6/8] Tworzę PR"
PR_URL=$(gh pr create --base main --head "$BRANCH" \
  --title "Scenario D run ${RUN_N} — DAST OWASP ZAP na Juice Shop" \
  --body "Eksperyment scenariusz D run ${RUN_N}: pomiar skuteczności OWASP ZAP w wykrywaniu udokumentowanych podatności OWASP Juice Shop. Bramka ZAP informacyjna (fail_action: false), workflow CAŁY zielony.")
PR_NUM="${PR_URL##*/}"

echo "  → PR utworzony: $PR_URL"

echo "[7/8] Czekam na pełen przebieg workflow (~14 min — wszystkie etapy)…"
sleep 12
RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId')
echo "  Run ID: $RUN_ID"
gh run watch "$RUN_ID" --exit-status >/dev/null 2>&1 || true

echo "[8/8] Pobieram artefakty (SARIF + raport ZAP HTML)"
mkdir -p "$SARIF_DIR"
gh run download "$RUN_ID" -D "$SARIF_DIR" >/dev/null 2>&1 || echo "  (problem z pobieraniem; sprawdź ręcznie)"

mkdir -p "$SCREENSHOTS_DIR"

RUN_URL="https://github.com/NarroW12/magisterka-devsecops-juice-shop/actions/runs/${RUN_ID}"

cat <<EOF

============================================================
WORKFLOW ZAKOŃCZONY — wszystkie etapy zielone, DAST raportowy
============================================================

  PR #${PR_NUM}:      ${PR_URL}
  Workflow run:       ${RUN_URL}

  Folder na screeny:  ${SCREENSHOTS_DIR}
  Artefakty w:        ${SARIF_DIR}/zap-baseline-report/

Po zrobieniu screenów uruchom:
  bash scripts/scenario_d_finish.sh ${RUN_N}

EOF
