#!/usr/bin/env bash
#
# scripts/scenario_c_variant_2_start.sh <run-number>
#
# Scenariusz C wariant 2 — IZOLACJA pojedynczej reguły. Dockerfile poprawny
# we wszystkim oprócz JEDNEJ rzeczy: brak instrukcji USER (kontener jako root).
#
# Oczekiwane wykrycie: Checkov CKV_DOCKER_3 (HIGH) → bramka blokuje.
# Hadolint nic nie powie (base image pinned, brak innych smelli).
# Trivy image nie znajdzie CVE (image z baseline build).
#
# Sprawdza ziarnistość bramki — czy pojedynczy konkretny błąd wystarczy.

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

BRANCH="scenario-c-variant-2-run-${RUN_N}"
SCREENSHOTS_DIR="docs/screenshots/scenario-c/variant-2/run-${RUN_N}"
SARIF_DIR="data/raw/scenario-c/variant-2/run-${RUN_N}"

echo "============================================================"
echo "SCENARIUSZ C WARIANT 2 RUN ${RUN_N} — START"
echo "  Izolowany błąd: brak instrukcji USER (Checkov CKV_DOCKER_3 HIGH)"
echo "============================================================"

echo "[1/8] Przełączam się na main i pulluję"
git checkout main
git pull --prune

echo "[2/8] Tworzę gałąź $BRANCH"
git checkout -b "$BRANCH"

echo "[3/8] Podmieniam apps/flask-app/Dockerfile na wersję bez USER"
cat > apps/flask-app/Dockerfile <<'DOCKERFILE_EOF'
# syntax=docker/dockerfile:1.7
# Scenariusz C wariant 2: izolacja Checkov CKV_DOCKER_3 (HIGH).
# Wszystko inne poprawne: pin base image, --no-cache-dir, HEALTHCHECK.
# Świadomie usunięta tylko instrukcja USER → kontener uruchomi się jako root.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# UWAGA: brak instrukcji USER — celowy błąd dla wariantu 2

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health').read()" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
DOCKERFILE_EOF

git add apps/flask-app/Dockerfile

echo "[4/8] Commit"
git -c user.email='jakub.omie@gmail.com' -c user.name='NarroW12' \
  commit -m "scenario C variant 2 run ${RUN_N}: remove USER from Dockerfile (isolate CKV_DOCKER_3)"

echo "[5/8] Push origin/$BRANCH"
git push -u origin "$BRANCH"

echo "[6/8] Tworzę PR"
PR_URL=$(gh pr create --base main --head "$BRANCH" \
  --title "Scenario C variant 2 run ${RUN_N} — izolowany błąd Dockerfile (brak USER)" \
  --body "Eksperyment scenariusz C wariant 2 run ${RUN_N}: weryfikacja czy POJEDYNCZY błąd (brak instrukcji USER) wystarczy by zablokować bramkę. Oczekiwane: Checkov CKV_DOCKER_3 (HIGH) → block. Hadolint czysty, Trivy image czysty. Ziarnistość bramki.")
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
WORKFLOW ZAKOŃCZONY — Etap 4 (IaC) zablokował bramkę (oczekiwane)
============================================================

  PR #${PR_NUM}:      ${PR_URL}
  Workflow run:       ${RUN_URL}
  Security tab:       ${SECURITY_URL}

  Folder na screeny:  ${SCREENSHOTS_DIR}
  SARIF zapisany w:   ${SARIF_DIR}

Sugestia nazw screenów (zgodnie z fazą 1):
  01-pr-blocked.png        — czerwony status Etap 4 na PR
  02-security-tab.png      — alert Checkov CKV_DOCKER_3
  03-ci-log.png            — log Etap 4 (Checkov failed)
  04-checkov-detail.png    — szczegóły reguły CKV_DOCKER_3 w SARIF/Security

Po zrobieniu screenów uruchom:
  bash scripts/scenario_c_variant_2_finish.sh ${RUN_N}

EOF
