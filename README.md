# magisterka-devsecops-juice-shop

Środowisko badawcze do pracy magisterskiej *„Analiza skuteczności mechanizmów DevSecOps w procesie wykrywania podatności oprogramowania w środowiskach chmurowych"*.

Repozytorium zawiera kompletny potok CI/CD oparty o GitHub Actions, integrujący narzędzia SAST, SCA, IaC scanning, secrets detection oraz DAST. Eksperyment realizuje cztery scenariusze testowe na dwóch aplikacjach testowych — prostej aplikacji Flask oraz OWASP Juice Shop.

## Scenariusze testowe

| Scenariusz | Opis | Mapowanie OWASP | Narzędzie |
|------------|------|------------------|-----------|
| A | Wyciek sekretu (klucz AWS) | CICD-SEC-6 | Gitleaks |
| B | Podatna biblioteka (PyYAML CVE-2020-14343) | A06:2021 | Trivy + Dependency-Check |
| C | Błędy konfiguracji Dockerfile | A05:2021 | Hadolint + Checkov |
| D | DAST na OWASP Juice Shop | A03:2021, A07:2021 | OWASP ZAP |

## Struktura repozytorium

| Ścieżka | Opis |
|---------|------|
| `apps/flask-app/` | Aplikacja testowa Python/Flask (baseline) |
| `apps/juice-shop/` | docker-compose dla OWASP Juice Shop |
| `.github/workflows/` | Workflow GitHub Actions z 6 etapami bezpieczeństwa |
| `configs/` | Konfiguracja narzędzi (Gitleaks, CodeQL, Hadolint, ZAP) |
| `scripts/` | Skrypty analityczne (parser SARIF → CSV, raport czasów) |
| `docs/` | Dokumentacja każdego scenariusza testowego |
| `data/raw/` | Surowe raporty z przebiegów eksperymentu (gitignore) |

## Uruchomienie lokalne

### Aplikacja Flask

```bash
cd apps/flask-app
pip install -r requirements.txt
python app.py
# lub w kontenerze
docker build -t flask-app .
docker run -p 5000:5000 flask-app
```

Aplikacja odpowiada na `http://localhost:5000`. Endpointy: `GET /health`, `GET /products`, `POST /login`.

### OWASP Juice Shop

```bash
cd apps/juice-shop
docker compose up -d
```

Aplikacja dostępna pod `http://localhost:3000`.

## Pre-commit hook

```bash
pip install pre-commit
pre-commit install
```

Od tej chwili każdy `git commit` automatycznie uruchomia Gitleaks oraz pozostałe walidacje opisane w `.pre-commit-config.yaml`.

## Powiązanie z pracą magisterską

Pełen opis projektu środowiska, modelu zagrożeń STRIDE oraz metodyki badań znajduje się w **rozdziale 3** pracy magisterskiej. Scenariusze testowe i zarejestrowane wyniki opisuje **rozdział 4**, a analizę i dyskusję — **rozdział 5**.

## Licencja

Kod tego repozytorium jest dostępny na licencji MIT (zobacz [LICENSE](LICENSE)).
Aplikacja OWASP Juice Shop, używana wyłącznie jako binarny obraz Dockera, podlega własnej licencji MIT (Bjoern Kimminich, projekt OWASP).
