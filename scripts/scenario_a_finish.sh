#!/usr/bin/env bash
#
# scripts/scenario_a_finish.sh <run-number>
#
# Druga połowa scenariusza A. Po zrobieniu i zapisaniu czterech screenów
# w docs/screenshots/scenario-a/run-<N>/ skrypt zamyka pull request scenariusza,
# kasuje zdalną gałąź, wraca lokalnie na main i pulluje.

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

echo "============================================================"
echo "SCENARIUSZ A RUN ${RUN_N} — FINISH"
echo "============================================================"

echo "[1/4] Weryfikuję screeny w ${SCREENSHOTS_DIR}"
EXPECTED=(01-precommit-blocked.png 02-pr-blocked.png 03-security-tab.png 04-ci-log.png)
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
  echo "  Skrypt mimo to dokończy sprzątanie, ale pamiętaj uzupełnić te pliki."
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
    --comment "Run ${RUN_N} ukończony — komplet dowodów zapisany w docs/screenshots/scenario-a/run-${RUN_N}/." \
    --delete-branch
fi

echo "[3/4] Wracam na main"
git checkout main
git pull --prune

# Lokalna gałąź mogła pozostać jeśli gh pr close --delete-branch skasował tylko zdalną
git branch -D "$BRANCH" 2>/dev/null || true

echo "[4/4] Stan końcowy"
ls -la "${SCREENSHOTS_DIR}/" 2>/dev/null | grep -E "\.png$" || true

cat <<EOF

============================================================
RUN ${RUN_N} ZAKOŃCZONY
============================================================

Następny run:
  bash scripts/scenario_a_start.sh $((RUN_N + 1))

EOF
