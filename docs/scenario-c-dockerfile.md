# Scenariusz C — Błędy konfiguracji Dockerfile

**Mapowanie zagrożeń:** A05:2021 „Security Misconfiguration", STRIDE — Elevation of Privilege
**Testowane narzędzia:** Hadolint (linting Dockerfile), Checkov (skanowanie konfiguracji), Trivy (skanowanie obrazu)

## Opis modyfikacji

Plik `apps/flask-app/Dockerfile` zostaje zastąpiony wersją zawierającą cztery typowe błędy konfiguracyjne:

1. **`FROM python:latest`** zamiast `python:3.12-slim` — naruszenie reguły Hadolint DL3007 (level `error`, blokujący przy `failure-threshold: error`) oraz Checkov CKV_DOCKER_7.
2. **Brak instrukcji `USER`** — kontener jest uruchamiany jako root. Naruszenie Checkov CKV_DOCKER_3 (severity HIGH).
3. **Brak instrukcji `HEALTHCHECK`** — naruszenie Checkov CKV_DOCKER_2 (severity HIGH).
4. **`apt-get install -y curl`** bez przypiętej wersji oraz bez czyszczenia cache — naruszenia Hadolint DL3008/DL3009 (level `warning`, nieblokujący samodzielnie, lecz istotny w raporcie).

Pełna zawartość celowo wadliwego Dockerfile generowana jest deterministycznie przez skrypt `scripts/scenario_c_start.sh`.

## Oczekiwany rezultat

1. Pre-commit hook **nie blokuje** commitu (nie sprawdza Dockerfile lint).
2. Workflow CI:
   - Etap 1 (Gitleaks) — przechodzi (brak sekretów).
   - Etap 2 (CodeQL SAST) — przechodzi (kod aplikacji nie zmieniony).
   - Etap 3 (SCA Trivy + Dependency-Check) — przechodzi (zależności nie zmienione).
   - **Etap 4 (Build + IaC) — pada na bramce IaC**, sygnalizowanej jednocześnie przez Hadolint (DL3007) oraz Checkov (CKV_DOCKER_2, _3, _7); dodatkowo Trivy image scan wykrywa średnie i niskie CVE w systemie operacyjnym najnowszego obrazu `python:latest`.
   - Etap 5 (DAST) — pominięty zgodnie z fail-fast.
3. Bramka bezpieczeństwa blokuje merge pull requesta.

## Procedura

Scenariusz został zautomatyzowany analogicznie do scenariuszy A i B — skryptami `scripts/scenario_c_start.sh <N>` oraz `scripts/scenario_c_finish.sh <N>`. Między ich wywołaniami badacz zapisuje cztery zrzuty ekranu z otwartego PR-a do `docs/screenshots/scenario-c/run-<N>/`.

## Wyniki pięciu powtórzeń

Eksperyment przeprowadzono w dniach 31 maja oraz 3 czerwca 2026 roku.

| Powtórzenie | PR | Workflow run | Etap 1 | Etap 2 | Etap 3 | Etap 4 (IaC) | Hadolint | Checkov | Trivy image | Czas trwania |
|-------------|----|--------------|--------|--------|--------|--------------|----------|---------|-------------|--------------|
| 1 | #26 | #46 | ✓ | ✓ | ✓ | ✗ blokada | ✓ | ✓ | ✓ | 4 min 27 s |
| 2 | #27 | #47 | ✓ | ✓ | ✓ | ✗ blokada | ✓ | ✓ | ✓ | 4 min 36 s |
| 3 | #28 | #48 | ✓ | ✓ | ✓ | ✗ blokada | ✓ | ✓ | ✓ | 4 min 58 s |
| 4 | #29 | #49 | ✓ | ✓ | ✓ | ✗ blokada | ✓ | ✓ | ✓ | 4 min 32 s |
| 5 | #30 | #50 | ✓ | ✓ | ✓ | ✗ blokada | ✓ | ✓ | ✓ | 4 min 31 s |
| **Średnia** | — | — | **5/5** | **5/5** | **5/5** | **5/5** | **5/5** | **5/5** | **5/5** | **4 min 37 s** |

## Wykryte naruszenia (Security tab GHAS)

W każdym z pięciu przebiegów Code Scanning rejestrował konsekwentny zestaw alertów. Najważniejsze z punktu widzenia bramki to:

| Tool | Rule ID | Severity | Opis |
|------|---------|----------|------|
| `checkov` | CKV_DOCKER_2 | HIGH | „Ensure that HEALTHCHECK instructions have been added to container images" |
| `checkov` | CKV_DOCKER_3 | HIGH | „Ensure that a user for the container has been created" |
| `checkov` | CKV_DOCKER_7 | LOW | „Ensure the base image uses a non latest version tag" |
| `Trivy` (image scan) | wiele CVE warstwy OS | MEDIUM/LOW | nieuniknione w obrazie `python:latest` |

Hadolint dodatkowo zwraca w logu workflow regułę DL3007 (level `error`), co bezpośrednio aktywuje bramkę (`failure-threshold: error`). Mimo że alerty Hadolint nie trafiają domyślnie do zakładki Code Scanning jako oddzielna wpisy SARIF, ich obecność jest udokumentowana w logu joba Etap 4 (przykładowo widoczna na zrzutach `04-hadolint-detail.png` każdego runa).

## Interpretacja wyników w kontekście hipotez badawczych

Z perspektywy hipotezy szczegółowej **H1** (≥ 80% detekcji wprowadzonych podatności) — scenariusz C osiągnął **100% wykrywalności** wszystkich czterech wprowadzonych klas naruszeń w każdym z pięciu powtórzeń. Co istotne, naruszenia były wykrywane jednocześnie przez **trzy niezależne narzędzia** (Hadolint, Checkov i Trivy), które stosują różne mechanizmy analizy — odpowiednio: regex/AST lint, policy-as-code z bazą OPA Rego oraz CVE matching względem bazy NVD/aquasec. Konwergencja tych trzech źródeł dowodu istotnie wzmacnia wiarygodność detekcji.

Z perspektywy hipotezy szczegółowej **H3** (≤ 200% narzutu czasu względem baseline) — średni czas trwania scenariusza C wynosi 277 s, czyli około **32% czasu baseline** (T_baseline = 863 s). Czas jest większy niż w scenariuszach A i B z powodu konieczności wykonania Etapu 3 (SCA, ~50 s) i Etapu 4 (build obrazu Dockera + lint + skan IaC + skan obrazu Trivy, ~3 min), zanim bramka się aktywuje. Mimo to hipoteza H3 pozostaje spełniona z dużym marginesem.

## Zebrane artefakty dowodowe

- **20 zrzutów ekranu** (5 powtórzeń × 4 kategorie: strona PR z bramką, Security tab z alertami Checkov, Summary workflow oraz szczegół Checkov/Hadolint) w `docs/screenshots/scenario-c/run-1..5/`.
- **5 raportów SARIF** w `data/raw/scenario-c/run-1..5/` (lokalnie, poza repo zgodnie z `.gitignore`).
- **5 zamkniętych pull requestów** w historii repozytorium (#26, #27, #28, #29, #30) z dołączonymi komentarzami botów `github-advanced-security` raportującymi inline wykryte naruszenia konfiguracji.

## Wariant 2 — izolowany brak USER

**Cel:** testowanie **ziarnistości bramki** — czy *jedna* konkretna reguła Checkov sama wystarczy, by zablokować PR? Czy detekcja jest "all or nothing", czy "rule-by-rule"?

### Konfiguracja

Dockerfile w wariancie 2 jest **identyczny z baseline** poza JEDNĄ rzeczą: usunięta jest instrukcja `USER`. Reszta pozostaje poprawna:

- pin `python:3.12-slim` (nie `latest`)
- `--no-cache-dir` przy `pip install`
- HEALTHCHECK obecny
- WORKDIR ustawiony

```dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
# UWAGA: brak USER — kontener uruchamia się jako root
EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health').read()" || exit 1
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
```

### Wyniki trzech powtórzeń

| Run | PR | Workflow run | Etap 4 IaC | Checkov | Hadolint | Trivy image |
|-----|----|--------------|------------|---------|----------|-------------|
| 1 | [#50](https://github.com/NarroW12/magisterka-devsecops-juice-shop/pull/50) | 27470824464 | ✓ zablokował | **1 finding (CKV_DOCKER_3)** | 0 | 5 informacyjnych |
| 2 | [#51](https://github.com/NarroW12/magisterka-devsecops-juice-shop/pull/51) | 27471088182 | ✓ zablokował | identyczny | 0 | identyczne |
| 3 | [#52](https://github.com/NarroW12/magisterka-devsecops-juice-shop/pull/52) | 27471293551 | ✓ zablokował | identyczny | 0 | identyczne |

### Pure izolacja

Jedna reguła Checkov (`CKV_DOCKER_3 — Ensure that a user for the container has been created`) wystarcza dla blokady bramki. Hadolint widzi czysty Dockerfile (brak USER nie jest jego regułą). Trivy image zwraca tylko informacyjne CVE w samym base image (Flask + pip — nie związane z eksperymentem).

**Wniosek dla H1/H3**: bramka jest **rule-granular**, nie "all or nothing". Pojedyncza krytyczna reguła Checkov ma siłę zablokować PR. Zgodne z polityką `soft_fail: false` w workflow.

## Wariant 3 — brak HEALTHCHECK + ADD zamiast COPY

**Cel:** testowanie **innego zestawu reguł** niż V2 (CKV_DOCKER_3) — czy bramka detektuje też inne klasy błędów Docker? Plus: czy dwa narzędzia (Hadolint + Checkov) niezależnie wykrywają ten sam pattern (ADD)?

### Korekta planu V3

Pierwotnie planowano `apt-get bez pin + curl | bash`. DL3008 (apt-get bez pin) jest jednak **IGNORED** w `configs/.hadolint.yaml` (`ignored: DL3008`), więc nie blokowałby. Zmieniono na:

- brak HEALTHCHECK → Checkov CKV_DOCKER_2 (HIGH, blokujący)
- ADD zamiast COPY → Hadolint DL3020 + Checkov CKV_DOCKER_4 (cross-tool!)

### Konfiguracja

```dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN groupadd --system app && useradd --system --gid app --no-create-home app
# ADD zamiast COPY — DL3020 + CKV_DOCKER_4
ADD requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
ADD app.py /app/app.py
USER app
EXPOSE 5000
# UWAGA: brak HEALTHCHECK — CKV_DOCKER_2
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
```

### Wyniki trzech powtórzeń

| Run | PR | Workflow run | Etap 4 IaC | Checkov | Hadolint | Cross-tool? |
|-----|----|--------------|------------|---------|----------|-------------|
| 1 | [#53](https://github.com/NarroW12/magisterka-devsecops-juice-shop/pull/53) | 27471449164 | ✓ zablokował | 3 (CKV_DOCKER_2 + 2× CKV_DOCKER_4) | 2 (2× DL3020) | ✓ (ADD wykryty przez OBA) |
| 2 | [#54](https://github.com/NarroW12/magisterka-devsecops-juice-shop/pull/54) | 27471802568 | ✓ zablokował | identyczne | identyczne | ✓ |
| 3 | [#55](https://github.com/NarroW12/magisterka-devsecops-juice-shop/pull/55) | 27471947799 | ✓ zablokował | identyczne | identyczne | ✓ |

### Defense-in-depth potwierdzony empirycznie

Wzorzec `ADD requirements.txt` wykryty **niezależnie przez DWA narzędzia**:
- **Hadolint DL3020** — "Use COPY instead of ADD for files and folders" (×2 — dla obu instrukcji ADD)
- **Checkov CKV_DOCKER_4** — "Ensure that COPY is used instead of ADD in Dockerfiles" (×2)

To **najmocniejszy empiryczny dowód** dla zalecanego defense-in-depth: gdyby user używał tylko Hadolint, znalazłby ten pattern; gdyby tylko Checkov, też. Dwa narzędzia → 100% redundancja na tym konkretnym pattern. Dla rozdz. 5: porównanie z asymetrią Trivy/Dep-Check w scenariuszu B V3 — różne typy detekcji mają różne profile pokrycia.

Dodatkowy CKV_DOCKER_2 (brak HEALTHCHECK) wykrywany tylko przez Checkov — Hadolint nie ma analogicznej reguły. Komplementarność narzędzi w obrębie scenariusza.

## Konsolidacja H3 z trzech wariantów scenariusza C

| Wariant | Charakterystyka | Findings łącznie | Czas Etap 4 | Wnioski |
|---------|-----------------|------------------|-------------|---------|
| 1 | 4 błędy razem (latest + brak USER/HEALTHCHECK + apt) | DL3007 + CKV_DOCKER_2/3/7 + Trivy image | ~5 min | Multi-rule, multi-tool |
| 2 | tylko brak USER | 1 finding (CKV_DOCKER_3) | ~5 min | Ziarnistość — 1 reguła wystarcza |
| 3 | brak HEALTHCHECK + ADD | 5 findings (Checkov 3 + Hadolint 2) | ~5 min | Cross-tool detection na ADD |

Trzy ortogonalne wymiary detekcji w obrębie jednego scenariusza:

1. **Volume** (V1) — wiele błędów razem, wiele findings
2. **Granularity** (V2) — pojedynczy błąd, pojedynczy finding, bramka nadal blokuje
3. **Redundancy** (V3) — ten sam błąd, dwa narzędzia, niezależnie wykrywają

Łącznie 11 niezależnych przebiegów potwierdzających H1/H3 dla Dockerfile (5 V1 + 3 V2 + 3 V3).

### Zebrane artefakty wariantów 2 i 3

- **24 zrzuty ekranu** (3 + 3 × 4) w `docs/screenshots/scenario-c/variant-{2,3}/run-1..3/`. V2 używa `04-checkov-detail.png`, V3 używa `04-sarif-detail.png` (różne pliki bo różne narzędzia w focus screenu).
- **6 raportów SARIF** w `data/raw/scenario-c/variant-{2,3}/run-1..3/` (z wszystkimi 4 narzędziami fazy 2 — Trivy, Hadolint, Checkov, gitleaks).
- **6 zamkniętych pull requestów**: V2 #50, #51, #52; V3 #53, #54, #55.
