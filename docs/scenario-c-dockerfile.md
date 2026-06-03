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
