#!/usr/bin/env bash
#
# scripts/scenario_b_start.sh <run-number>
#
# Scenariusz B — wprowadzenie podatnej biblioteki PyYAML 5.3.1 dotkniętej
# CVE-2020-14343 (CVSS 9.8 CRITICAL — arbitrary code execution).
#
# Skrypt tworzy gałąź scenario-b-run-<N>, dopisuje linię PyYAML==5.3.1 do
# apps/flask-app/requirements.txt, robi commit (pre-commit nie blokuje —
# brak sekretów), wystawia PR, czeka aż workflow padnie na Etapie 3 (SCA),
# pobiera SARIF do data/raw/scenario-b/run-<N>/.

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

BRANCH="scenario-b-run-${RUN_N}"
SCREENSHOTS_DIR="docs/screenshots/scenario-b/run-${RUN_N}"
SARIF_DIR="data/raw/scenario-b/run-${RUN_N}"

echo "============================================================"
echo "SCENARIUSZ B RUN ${RUN_N} — START"
echo "  Podatna biblioteka: PyYAML 5.3.1 (CVE-2020-14343)"
echo "============================================================"

echo "[1/8] Przełączam się na main i pulluję"
git checkout main
git pull --prune

echo "[2/8] Tworzę gałąź $BRANCH"
git checkout -b "$BRANCH"

echo "[3/8] Dodaję podatną wersję PyYAML do apps/flask-app/requirements.txt"
# Sprawdź czy linia już istnieje
if grep -q "^PyYAML==5.3.1" apps/flask-app/requirements.txt; then
  echo "  (PyYAML==5.3.1 już obecny — pomijam dodawanie)"
else
  printf "\n# Scenariusz B: celowo podatna wersja, CVE-2020-14343 (CVSS 9.8 CRITICAL)\nPyYAML==5.3.1\n" >> apps/flask-app/requirements.txt
fi
git add apps/flask-app/requirements.txt

echo "[4/8] Commit"
git -c user.email='jakub.omie@gmail.com' -c user.name='NarroW12' \
  commit -m "scenario B run ${RUN_N}: introduce vulnerable PyYAML 5.3.1 (CVE-2020-14343)"

echo "[5/8] Push origin/$BRANCH"
git push -u origin "$BRANCH"

echo "[6/8] Tworzę PR"
PR_URL=$(gh pr create --base main --head "$BRANCH" \
  --title "Scenario B run ${RUN_N} — podatna biblioteka (PyYAML 5.3.1)" \
  --body "Eksperyment scenariusz B run ${RUN_N}: weryfikacja skuteczności Trivy oraz OWASP Dependency-Check w wykrywaniu CVE-2020-14343 w bibliotece PyYAML 5.3.1.")
PR_NUM="${PR_URL##*/}"

echo "  → PR utworzony: $PR_URL"

echo "[7/8] Czekam aż workflow padnie na Etapie 3 (SCA)…"
sleep 8
RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status >/dev/null 2>&1 || true

echo "[8/8] Pobieram artefakt SARIF"
mkdir -p "$SARIF_DIR"
gh run download "$RUN_ID" -D "$SARIF_DIR" >/dev/null 2>&1 || echo "  (brak artefaktów do pobrania)"

mkdir -p "$SCREENSHOTS_DIR"

SECURITY_URL="https://github.com/NarroW12/magisterka-devsecops-juice-shop/security/code-scanning?query=is%3Aopen+pr%3A${PR_NUM}"
RUN_URL="https://github.com/NarroW12/magisterka-devsecops-juice-shop/actions/runs/${RUN_ID}"

cat <<EOF

============================================================
WORKFLOW ZAKOŃCZONY — Etap 3 (SCA) zablokował bramkę
============================================================

  PR #${PR_NUM}:      ${PR_URL}
  Workflow run:       ${RUN_URL}
  Security tab:       ${SECURITY_URL}

  Folder na screeny:  ${SCREENSHOTS_DIR}
  SARIF zapisany w:   ${SARIF_DIR}

Po zrobieniu screenów uruchom:
  bash scripts/scenario_b_finish.sh ${RUN_N}

EOF
