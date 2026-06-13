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
