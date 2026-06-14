#!/usr/bin/env bash
#
# scripts/scenario_b_variant_2_start.sh <run-number>
#
# Scenariusz B wariant 2 — wprowadzenie podatnej biblioteki paramiko 2.4.0
# dotkniętej CVE-2018-7750 (CVSS 9.8 CRITICAL — authentication bypass w SSH
# pre-auth, prowadzące do RCE). Inna klasa błędu niż wariant 1 (PyYAML /
# improper input validation / RCE deserializacyjne).
#
# Wybór biblioteki: początkowo planowane Pillow 8.0.0 (CVE-2021-25287) odpadło
# — wymaga libjpeg-dev na runnerze, brak Python 3.12 wheels, padał Etap 2 CodeQL
# przy pip install zamiast Etap 3 SCA. paramiko 2.4.0 jest pure Python.
#
# Skrypt tworzy gałąź scenario-b-variant-2-run-<N>, dopisuje linię
# paramiko==2.4.0 do apps/flask-app/requirements.txt, robi commit, wystawia PR,
# czeka aż workflow padnie na Etapie 3 (SCA), pobiera SARIF do
# data/raw/scenario-b/variant-2/run-<N>/.

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

BRANCH="scenario-b-variant-2-run-${RUN_N}"
SCREENSHOTS_DIR="docs/screenshots/scenario-b/variant-2/run-${RUN_N}"
SARIF_DIR="data/raw/scenario-b/variant-2/run-${RUN_N}"

echo "============================================================"
echo "SCENARIUSZ B WARIANT 2 RUN ${RUN_N} — START"
echo "  Podatna biblioteka: paramiko 2.4.0 (CVE-2018-7750, CVSS 9.8 CRITICAL)"
echo "============================================================"

echo "[1/8] Przełączam się na main i pulluję"
git checkout main
git pull --prune

echo "[2/8] Tworzę gałąź $BRANCH"
git checkout -b "$BRANCH"

echo "[3/8] Dodaję podatną wersję paramiko do apps/flask-app/requirements.txt"
if grep -q "^paramiko==2.4.0" apps/flask-app/requirements.txt; then
  echo "  (paramiko==2.4.0 już obecny — pomijam dodawanie)"
else
  printf "\n# Scenariusz B wariant 2: celowo podatna wersja, CVE-2018-7750 (CVSS 9.8 CRITICAL)\nparamiko==2.4.0\n" >> apps/flask-app/requirements.txt
fi
git add apps/flask-app/requirements.txt

echo "[4/8] Commit"
git -c user.email='jakub.omie@gmail.com' -c user.name='NarroW12' \
  commit -m "scenario B variant 2 run ${RUN_N}: introduce vulnerable paramiko 2.4.0 (CVE-2018-7750)"

echo "[5/8] Push origin/$BRANCH"
git push -u origin "$BRANCH"

echo "[6/8] Tworzę PR"
PR_URL=$(gh pr create --base main --head "$BRANCH" \
  --title "Scenario B variant 2 run ${RUN_N} — podatna biblioteka (paramiko 2.4.0)" \
  --body "Eksperyment scenariusz B wariant 2 run ${RUN_N}: weryfikacja skuteczności Trivy oraz OWASP Dependency-Check w wykrywaniu CVE-2018-7750 (SSH pre-auth bypass / RCE) w bibliotece paramiko 2.4.0. Inna klasa błędu niż wariant 1 (PyYAML / deserialization RCE).")
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
WORKFLOW ZAKOŃCZONY — Etap 3 (SCA) zablokował bramkę (oczekiwane)
============================================================

  PR #${PR_NUM}:      ${PR_URL}
  Workflow run:       ${RUN_URL}
  Security tab:       ${SECURITY_URL}

  Folder na screeny:  ${SCREENSHOTS_DIR}
  SARIF zapisany w:   ${SARIF_DIR}

Po zrobieniu screenów uruchom:
  bash scripts/scenario_b_variant_2_finish.sh ${RUN_N}

EOF
