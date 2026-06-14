#!/usr/bin/env bash
#
# scripts/scenario_a_variant_2_start.sh <run-number>
#
# Pierwsza połowa scenariusza A wariant 2 (GitHub Personal Access Token).
# Tworzy świeżą gałąź scenario-a-variant-2-run-<N>, generuje
# apps/flask-app/.env.example z fałszywym tokenem ghp_..., wykonuje
# commit --no-verify (obejście pre-commit hooka), wystawia pull request,
# czeka aż workflow padnie na Etapie 1 (Gitleaks) i pobiera artefakt SARIF
# do data/raw/scenario-a/variant-2/run-<N>/.
#
# Po wykonaniu wyświetla linki, pod które należy wejść w przeglądarce
# aby zrobić cztery zrzuty ekranu, oraz docelowe ścieżki dla każdego z nich.
#
# Po zrobieniu screenów uruchom: scripts/scenario_a_variant_2_finish.sh <N>

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

BRANCH="scenario-a-variant-2-run-${RUN_N}"
SCREENSHOTS_DIR="docs/screenshots/scenario-a/variant-2/run-${RUN_N}"
SARIF_DIR="data/raw/scenario-a/variant-2/run-${RUN_N}"

echo "============================================================"
echo "SCENARIUSZ A WARIANT 2 RUN ${RUN_N} — START"
echo "============================================================"

echo "[1/8] Przełączam się na main i pulluję"
git checkout main
git pull --prune

echo "[2/8] Tworzę gałąź $BRANCH"
git checkout -b "$BRANCH"

echo "[3/8] Tworzę apps/flask-app/.env.example z fałszywym GitHub PAT"
cat > apps/flask-app/.env.example <<'ENV_EOF'
# Application environment template — Scenariusz A wariant 2 (eksperyment).
#
# UWAGA: ten plik celowo zawiera fałszywy token GitHub Personal Access Token
# w celu zweryfikowania skuteczności narzędzia Gitleaks. Token NIE jest
# powiązany z żadnym realnym kontem GitHub.

# Scenariusz A wariant 2: celowy wyciek GitHub PAT
GITHUB_TOKEN=ghp_aBcDeF1234567890abcdef1234567890abcd

DEBUG=False
LOG_LEVEL=INFO
ENV_EOF
git add apps/flask-app/.env.example

echo "[4/8] Commit --no-verify (obejście pre-commit hooka)"
git -c user.email='jakub.omie@gmail.com' -c user.name='NarroW12' \
  commit --no-verify -m "scenario A variant 2 run ${RUN_N}: introduce fake GitHub PAT"

echo "[5/8] Push origin/$BRANCH"
git push -u origin "$BRANCH"

echo "[6/8] Tworzę PR"
PR_URL=$(gh pr create --base main --head "$BRANCH" \
  --title "Scenario A variant 2 run ${RUN_N} — wyciek sekretu (fałszywy GitHub PAT)" \
  --body "Eksperyment scenariusz A wariant 2 run ${RUN_N}: weryfikacja skuteczności Gitleaks w wykrywaniu fałszywego GitHub Personal Access Token w pliku .env.example.")
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

# Dla runów > 1 — skopiuj 01-precommit-blocked.png z run-1. Pre-commit hook
# produkuje deterministyczny output dla identycznego payloadu, więc treść
# screena jest niezmienna; oszczędza ręcznej pracy bez utraty informacji.
if [[ "$RUN_N" -gt 1 ]]; then
  SRC_01="docs/screenshots/scenario-a/variant-2/run-1/01-precommit-blocked.png"
  DST_01="${SCREENSHOTS_DIR}/01-precommit-blocked.png"
  if [[ -f "$SRC_01" ]]; then
    cp "$SRC_01" "$DST_01"
    echo "  → Skopiowano 01-precommit-blocked.png z run-1 (treść deterministyczna)"
  fi
fi

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
  bash scripts/scenario_a_variant_2_finish.sh ${RUN_N}

EOF
