#!/usr/bin/env bash
#
# scripts/scenario_c_start.sh <run-number>
#
# Scenariusz C — błędy konfiguracji Dockerfile.
# Wprowadza cztery typowe naruszenia best-practices Dockera:
#   1. FROM python:latest      → DL3007 (Hadolint ERROR, blokuje failure-threshold)
#   2. brak instrukcji USER    → CKV_DOCKER_3 (Checkov HIGH, kontener jako root)
#   3. brak HEALTHCHECK        → CKV_DOCKER_2 (Checkov HIGH)
#   4. apt-get bez pinned ver  → DL3008/DL3009 (Hadolint WARNING)

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

BRANCH="scenario-c-run-${RUN_N}"
SCREENSHOTS_DIR="docs/screenshots/scenario-c/run-${RUN_N}"
SARIF_DIR="data/raw/scenario-c/run-${RUN_N}"

echo "============================================================"
echo "SCENARIUSZ C RUN ${RUN_N} — START"
echo "  Wprowadza błędy w apps/flask-app/Dockerfile"
echo "============================================================"

echo "[1/8] Przełączam się na main i pulluję"
git checkout main
git pull --prune

echo "[2/8] Tworzę gałąź $BRANCH"
git checkout -b "$BRANCH"

echo "[3/8] Podmieniam apps/flask-app/Dockerfile na wersję z błędami"
cat > apps/flask-app/Dockerfile <<'DOCKERFILE_EOF'
# Scenariusz C: celowo wprowadzone błędy konfiguracji dla weryfikacji
# skuteczności narzędzi Hadolint, Checkov oraz Trivy (image scan).
# Naruszenia (oczekiwane wykrycia):
#   1. DL3007    — użycie tagu `latest`
#   2. CKV_DOCKER_3 — brak instrukcji USER (kontener jako root)
#   3. CKV_DOCKER_2 — brak HEALTHCHECK
#   4. DL3008/9  — apt-get bez pinned wersji + brak czyszczenia cache

FROM python:latest

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y curl

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
DOCKERFILE_EOF

git add apps/flask-app/Dockerfile

echo "[4/8] Commit"
git -c user.email='jakub.omie@gmail.com' -c user.name='NarroW12' \
  commit -m "scenario C run ${RUN_N}: introduce Dockerfile misconfigurations"

echo "[5/8] Push origin/$BRANCH"
git push -u origin "$BRANCH"

echo "[6/8] Tworzę PR"
PR_URL=$(gh pr create --base main --head "$BRANCH" \
  --title "Scenario C run ${RUN_N} — błędy konfiguracji Dockerfile" \
  --body "Eksperyment scenariusz C run ${RUN_N}: weryfikacja skuteczności Hadolint, Checkov oraz Trivy (image scan) w wykrywaniu typowych błędów konfiguracji Dockerfile (latest tag, brak USER, brak HEALTHCHECK, apt-get bez pinned wersji).")
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
WORKFLOW ZAKOŃCZONY — Etap 4 (Build + IaC) zablokował bramkę
============================================================

  PR #${PR_NUM}:      ${PR_URL}
  Workflow run:       ${RUN_URL}
  Security tab:       ${SECURITY_URL}

  Folder na screeny:  ${SCREENSHOTS_DIR}
  SARIF zapisany w:   ${SARIF_DIR}

Po zrobieniu screenów uruchom:
  bash scripts/scenario_c_finish.sh ${RUN_N}

EOF
