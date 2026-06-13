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
