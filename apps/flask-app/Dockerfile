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
