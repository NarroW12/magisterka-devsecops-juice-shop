#!/usr/bin/env bash
#
# scripts/scenario_a_start.sh <run-number>
#
# Pierwsza połowa scenariusza A (wyciek sekretów). Tworzy świeżą gałąź
# scenario-a-run-<N>, generuje apps/flask-app/config.py z fałszywym kluczem
# AWS, wykonuje commit --no-verify (obejście pre-commit hooka), wystawia
# pull request, czeka aż workflow padnie na Etapie 1 (Gitleaks) i pobiera
# artefakt SARIF do data/raw/scenario-a/run-<N>/.
#
# Po wykonaniu wyświetla linki, pod które należy wejść w przeglądarce
# aby zrobić cztery zrzuty ekranu, oraz docelowe ścieżki dla każdego z nich.
#
# Po zrobieniu screenów uruchom: scripts/scenario_a_finish.sh <N>

set -euo pipefail

usage() {
  echo "Użycie: $0 <run-number>"
  echo "Przykład: $0 2"
  exit 1
}

[[ "$#" -eq 1 ]] || usage
RUN_N="$1"
[[ "$RUN_N" =~ ^[0-9]+$ ]] || usage

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

BRANCH="scenario-a-run-${RUN_N}"
SCREENSHOTS_DIR="docs/screenshots/scenario-a/run-${RUN_N}"
SARIF_DIR="data/raw/scenario-a/run-${RUN_N}"

echo "============================================================"
echo "SCENARIUSZ A RUN ${RUN_N} — START"
echo "============================================================"

echo "[1/8] Przełączam się na main i pulluję"
git checkout main
git pull --prune

echo "[2/8] Tworzę gałąź $BRANCH"
git checkout -b "$BRANCH"

echo "[3/8] Tworzę apps/flask-app/config.py z fałszywym kluczem AWS"
cat > apps/flask-app/config.py <<'CONFIG_EOF'
"""Application configuration — Scenariusz A (eksperyment).

UWAGA: ten plik celowo zawiera fałszywe poświadczenia AWS w celu
zweryfikowania skuteczności narzędzia Gitleaks. Klucz NIE jest powiązany
z żadnym realnym kontem AWS.
"""

# Scenariusz A: celowy wyciek sekretu (fałszywy klucz AWS)
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

DEBUG = False
CONFIG_EOF
git add apps/flask-app/config.py

echo "[4/8] Commit --no-verify (obejście pre-commit hooka)"
git -c user.email='jakub.omie@gmail.com' -c user.name='NarroW12' \
  commit --no-verify -m "scenario A run ${RUN_N}: introduce fake AWS access key"

echo "[5/8] Push origin/$BRANCH"
git push -u origin "$BRANCH"

echo "[6/8] Tworzę PR"
PR_URL=$(gh pr create --base main --head "$BRANCH" \
  --title "Scenario A run ${RUN_N} — wyciek sekretu (fałszywy klucz AWS)" \
  --body "Eksperyment scenariusz A run ${RUN_N}: weryfikacja skuteczności Gitleaks w wykrywaniu fałszywego klucza AWS.")
PR_NUM="${PR_URL##*/}"

echo "  → PR utworzony: $PR_URL"

echo "[7/8] Czekam aż workflow padnie na Etapie 1 (Gitleaks)…"
sleep 8
RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status >/dev/null 2>&1 || true

echo "[8/8] Pobieram artefakt SARIF"
mkdir -p "$SARIF_DIR"
gh run download "$RUN_ID" -D "$SARIF_DIR" >/dev/null 2>&1 || echo "  (brak artefaktów do pobrania)"

mkdir -p "$SCREENSHOTS_DIR"

# Wynik dla użytkownika: linki + ścieżki screenów
SECURITY_URL="https://github.com/NarroW12/magisterka-devsecops-juice-shop/security/code-scanning?query=is%3Aopen+pr%3A${PR_NUM}"
RUN_URL="https://github.com/NarroW12/magisterka-devsecops-juice-shop/actions/runs/${RUN_ID}"

cat <<EOF

============================================================
WORKFLOW ZAKOŃCZONY — Etap 1 zablokował bramkę (oczekiwane)
============================================================

  PR #${PR_NUM}:      ${PR_URL}
  Workflow run:       ${RUN_URL}
  Security tab:       ${SECURITY_URL}

  Folder na screeny:  ${SCREENSHOTS_DIR}
  SARIF zapisany w:   ${SARIF_DIR}

Po zrobieniu screenów uruchom:
  bash scripts/scenario_a_finish.sh ${RUN_N}

EOF
