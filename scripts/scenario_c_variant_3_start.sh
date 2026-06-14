#!/usr/bin/env bash
#
# scripts/scenario_c_variant_3_start.sh <run-number>
#
# Scenariusz C wariant 3 — INNY zestaw reguł niż V1 i V2:
#   - brak HEALTHCHECK → Checkov CKV_DOCKER_2 (HIGH, blokuje)
#   - ADD zamiast COPY → Hadolint DL3020 (INFO, raportowane, nie blokuje)
#
# Sprawdza że bramka detektuje kombinację Checkov-blokujący + Hadolint-info
# w innej konstelacji niż V2 (CKV_DOCKER_3) i V1 (4 błędy razem).

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

BRANCH="scenario-c-variant-3-run-${RUN_N}"
SCREENSHOTS_DIR="docs/screenshots/scenario-c/variant-3/run-${RUN_N}"
SARIF_DIR="data/raw/scenario-c/variant-3/run-${RUN_N}"

echo "============================================================"
echo "SCENARIUSZ C WARIANT 3 RUN ${RUN_N} — START"
echo "  Kombinacja: brak HEALTHCHECK (Checkov CKV_DOCKER_2 HIGH) + ADD zamiast COPY (Hadolint DL3020 info)"
echo "============================================================"

echo "[1/8] Przełączam się na main i pulluję"
git checkout main
git pull --prune

echo "[2/8] Tworzę gałąź $BRANCH"
git checkout -b "$BRANCH"

echo "[3/8] Podmieniam apps/flask-app/Dockerfile na wersję bez HEALTHCHECK + ADD"
cat > apps/flask-app/Dockerfile <<'DOCKERFILE_EOF'
# syntax=docker/dockerfile:1.7
# Scenariusz C wariant 3: inny zestaw błędów niż V2.
#   - brak HEALTHCHECK → Checkov CKV_DOCKER_2 (HIGH, blokuje)
#   - ADD zamiast COPY → Hadolint DL3020 (INFO, raportuje nie blokuje)
# USER zachowany (CKV_DOCKER_3 nie strzela).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

RUN groupadd --system app && useradd --system --gid app --no-create-home app

# ADD zamiast COPY — Hadolint DL3020 (informational)
ADD requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

ADD app.py /app/app.py

USER app

EXPOSE 5000

# UWAGA: brak HEALTHCHECK — celowy błąd dla wariantu 3

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
DOCKERFILE_EOF

git add apps/flask-app/Dockerfile

echo "[4/8] Commit"
git -c user.email='jakub.omie@gmail.com' -c user.name='NarroW12' \
  commit -m "scenario C variant 3 run ${RUN_N}: remove HEALTHCHECK + use ADD instead of COPY"

echo "[5/8] Push origin/$BRANCH"
git push -u origin "$BRANCH"

echo "[6/8] Tworzę PR"
PR_URL=$(gh pr create --base main --head "$BRANCH" \
  --title "Scenario C variant 3 run ${RUN_N} — kombinacja: brak HEALTHCHECK + ADD" \
  --body "Eksperyment scenariusz C wariant 3 run ${RUN_N}: inny zestaw reguł niż V1/V2. Checkov CKV_DOCKER_2 (HIGH) blokuje. Hadolint DL3020 raportuje informacyjnie ADD. USER zachowany.")
PR_NUM="${PR_URL##*/}"

echo "  → PR utworzony: $PR_URL"

echo "[7/8] Czekam aż workflow padnie na Etapie 4 (IaC)…"
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
WORKFLOW ZAKOŃCZONY — Etap 4 (IaC) zablokował bramkę
============================================================

  PR #${PR_NUM}:      ${PR_URL}
  Workflow run:       ${RUN_URL}
  Security tab:       ${SECURITY_URL}

  Folder na screeny:  ${SCREENSHOTS_DIR}
  SARIF zapisany w:   ${SARIF_DIR}

Sugestia nazw screenów:
  01-pr-blocked.png        — czerwony status Etap 4
  02-security-tab.png      — alerty CKV_DOCKER_2 + DL3020
  03-ci-log.png            — log Etap 4 (Checkov failed na CKV_DOCKER_2)
  04-sarif-detail.png      — szczegóły alertów (Checkov + Hadolint)

Po zrobieniu screenów uruchom:
  bash scripts/scenario_c_variant_3_finish.sh ${RUN_N}

EOF
