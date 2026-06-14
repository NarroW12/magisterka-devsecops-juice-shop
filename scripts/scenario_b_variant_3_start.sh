#!/usr/bin/env bash
#
# scripts/scenario_b_variant_3_start.sh <run-number>
#
# Scenariusz B wariant 3 — KONTROLA NEGATYWNA. Wprowadzenie biblioteki
# gunicorn 20.0.0 dotkniętej CVE-2024-1135 (CVSS 7.5 HIGH — HTTP Request
# Smuggling). CVSS poniżej progu bramki (`failOnCVSS 9` w Dep-Check,
# `severity: CRITICAL` w Trivy), więc:
#
#   - Etap 3 SCA RAPORTUJE finding (Trivy + Dep-Check), ale
#   - Etap 3 NIE BLOKUJE PR (gate przejdzie z PASS)
#   - Workflow kończy się sukcesem (wszystkie etapy zielone)
#
# To kluczowy element narracji H2 — bramka respektuje politykę severity,
# nie blokuje "wszystkiego po kolei". Wynik kontrastowy do wariantu 2
# (paramiko 2.4.0, CVSS 9.8 → bramka blokuje).
#
# UWAGA: requirements.txt fazy 1 zawiera już gunicorn==22.0.0. Wariant 3
# zastępuje tę linię (downgrade), nie dopisuje.

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
SARIF_DIR="data/raw/scenario-b/variant-3/run-${RUN_N}"

echo "============================================================"
echo "SCENARIUSZ B WARIANT 3 RUN ${RUN_N} — START (kontrola negatywna)"
echo "  Podatna biblioteka: gunicorn 20.0.0 (CVE-2024-1135, CVSS 7.5 HIGH)"
echo "  Oczekiwane: bramka NIE blokuje (CVSS < 9.0)"
echo "============================================================"

echo "[1/8] Przełączam się na main i pulluję"
git checkout main
git pull --prune

echo "[2/8] Tworzę gałąź $BRANCH"
git checkout -b "$BRANCH"

echo "[3/8] Zamieniam gunicorn==22.0.0 na podatną wersję 20.0.0"
if grep -q "^gunicorn==20.0.0" apps/flask-app/requirements.txt; then
  echo "  (gunicorn==20.0.0 już obecny — pomijam)"
else
  # Usuwamy starą linię gunicorn (sed -d kompatybilne z BSD i GNU sed)
  # i dopisujemy podatną wersję na końcu pliku.
  sed -i.bak -E '/^gunicorn==22\.0\.0$/d' apps/flask-app/requirements.txt
  rm -f apps/flask-app/requirements.txt.bak
  printf "\n# Scenariusz B wariant 3: celowo podatna wersja, CVE-2024-1135 (CVSS 7.5 HIGH — poniżej progu bramki)\ngunicorn==20.0.0\n" >> apps/flask-app/requirements.txt
fi
git add apps/flask-app/requirements.txt

echo "[4/8] Commit"
git -c user.email='jakub.omie@gmail.com' -c user.name='NarroW12' \
  commit -m "scenario B variant 3 run ${RUN_N}: downgrade gunicorn to vulnerable 20.0.0 (CVE-2024-1135, below gate threshold)"

echo "[5/8] Push origin/$BRANCH"
git push -u origin "$BRANCH"

echo "[6/8] Tworzę PR"
PR_URL=$(gh pr create --base main --head "$BRANCH" \
  --title "Scenario B variant 3 run ${RUN_N} — kontrola negatywna (gunicorn 20.0.0, HIGH 7.5)" \
  --body "Eksperyment scenariusz B wariant 3 run ${RUN_N}: KONTROLA NEGATYWNA. Trivy/Dep-Check wykrywają CVE-2024-1135 (CVSS 7.5 HIGH), ale bramka NIE blokuje (próg CRITICAL). Demonstruje że bramka respektuje politykę severity zamiast blokować wszystko.")
PR_NUM="${PR_URL##*/}"

echo "  → PR utworzony: $PR_URL"

echo "[7/8] Czekam aż workflow zakończy się sukcesem (bramka nie blokuje)…"
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
WORKFLOW ZAKOŃCZONY — wszystkie etapy SUCCESS (oczekiwane dla kontroli negatywnej)
============================================================

  PR #${PR_NUM}:      ${PR_URL}
  Workflow run:       ${RUN_URL}
  Security tab:       ${SECURITY_URL}

  Folder na screeny:  ${SCREENSHOTS_DIR}
  SARIF zapisany w:   ${SARIF_DIR}

UWAGA: screen 01 i 03 będą inne niż w wariancie 2 — pokazują PASSING gate,
nie BLOCKED. Sugestia nazw:
  01-pr-passed.png        — PR z zieloną sumą statusów
  02-security-tab.png     — alert HIGH widoczny w GHAS (raportowany, nieblokujący)
  03-ci-log.png           — Etap 3 SCA: success (mimo wykrycia HIGH)
  04-sarif-detail.png     — szczegóły alertu z CVSS 7.5

Po zrobieniu screenów uruchom:
  bash scripts/scenario_b_variant_3_finish.sh ${RUN_N}

EOF
