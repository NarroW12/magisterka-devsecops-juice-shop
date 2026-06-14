# Plan rozszerzenia eksperymentu — warianty

Dokument planistyczny dla **drugiej fazy** części empirycznej pracy magisterskiej. Pierwsza faza (5 powtórzeń każdego scenariusza z tą samą modyfikacją) została zakończona i zmergowana do `main`. Druga faza dodaje warianty z różnymi podatnościami w obrębie każdego scenariusza, co istotnie wzmacnia ważność zewnętrzną wyników.

## Stan obecny (po pierwszej fazie)

Wykonane eksperymenty: **20 runów łącznie** (4 scenariusze × 5 powtórzeń jednej modyfikacji każdy).

| Scenariusz | Wariant 1 (wykonany) | Status |
|------------|-----------------------|--------|
| A — sekrety | AWS Access Key ID (`AKIAIOSFODNN7EXAMPLE`) w `apps/flask-app/config.py` | ✅ 5/5 |
| B — podatna biblioteka | PyYAML 5.3.1 (CVE-2020-14343) w `apps/flask-app/requirements.txt` | ✅ 5/5 |
| C — Dockerfile | 4 błędy razem (latest tag + brak USER + brak HEALTHCHECK + apt-get) | ✅ 5/5 |
| D — DAST | Pełny scan ZAP `bkimminich/juice-shop:v17.2.0` (bez autentykacji) | ✅ 5/5 |

**Wynik pierwszej fazy:** udowodniony 100% determinizm bramek i powtarzalność wyników.

## Cel drugiej fazy

Po każdym scenariuszu (A, B, C, D) — dodanie nowych wariantów z różnymi typami podatności/konfiguracji.

**Stan finalny po wykonaniu fazy 2:**

| Scenariusz | Wariant 2 | Wariant 3 | Łącznie |
|------------|-----------|-----------|---------|
| A | ✅ 3 runy | — pominięty | 3 runy |
| B | ✅ 3 runy | ✅ 3 runy (kontrola negatywna) | 6 runów |
| C | ✅ 3 runy | ✅ 3 runy | 6 runów |
| D | — pominięty | — pominięty | 0 runów |
| **Razem** | — | — | **15 runów** |

**Decyzje skalujące:** w trakcie fazy 2 zredukowano docelowy liczbę runów per wariant z 5 do **3** (po pytaniu metodologicznym użytkownika 2026-06-13). Trzy runy nadal dowodzą determinizmu, oszczędzając ~40% czasu CI. Plus: świadome pominięcia wariantów A V3, D V2, D V3 (uzasadnienia w opisach scenariuszy).

**Wraz z fazą 1 (20 runów)** — łącznie **35 runów** w eksperymencie.

## Plan szczegółowy — warianty per scenariusz

### Scenariusz A — wyciek sekretów

| Wariant | Typ sekretu | Konkretny payload | Plik | Gitleaks rule | Status |
|---------|------------|--------------------|------|---------------|--------|
| 1 | AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` + secret | `apps/flask-app/config.py` | `aws-access-token`, `experiment-aws-access-key-id`, `experiment-aws-secret-access-key` (3 findings) | ✅ 5/5 (faza 1) |
| 2 | GitHub Personal Access Token | `ghp_aBcDeF1234567890abcdef1234567890abcd` | `apps/flask-app/.env.example` | `github-pat` (1 finding — brak custom rule) | ✅ 3/3 (faza 2) |
| ~~3~~ | ~~Klucz prywatny RSA~~ | — | — | — | **POMINIĘTY** |

**Wariant 3 (RSA) pominięty świadomie** — V1 (AWS, 3 reguły) + V2 (GitHub PAT, 1 reguła default) już testują 2 ortogonalne klasy detektora Gitleaks. Trzecia klasa (RSA private key) byłaby redundantna względem demonstracji H1.

### Scenariusz B — podatna biblioteka

| Wariant | Biblioteka + wersja | CVE | CVSS | Klasa | Wynik bramki | Status |
|---------|---------------------|-----|------|-------|--------------|--------|
| 1 | PyYAML 5.3.1 | CVE-2020-14343 | 9.8 CRITICAL | Improper Input Validation (RCE deserializacyjne) | **BLOCK** | ✅ 5/5 (faza 1) |
| 2 | **paramiko 2.4.0** | CVE-2018-7750 | 9.8 CRITICAL | SSH pre-auth bypass / RCE | **BLOCK** | ✅ 3/3 (faza 2) |
| 3 | **gunicorn 20.0.0** | CVE-2024-1135 | 7.5 HIGH (Trivy podaje 8.2) | HTTP Request Smuggling | **PASS** (kontrola negatywna) | ✅ 3/3 (faza 2) |

**Substytucja Pillow → paramiko (V2)**: pierwotnie planowano Pillow 8.0.0, ale brak wheels dla Python 3.12 + brak `libjpeg-dev` na runnerze powodował fail Etap 2 (CodeQL `pip install`) zamiast Etap 3 (SCA). paramiko 2.4.0 jest pure Python — czysty test SCA gate'a.

**V3 to świadoma kontrola negatywna**: bramka skonfigurowana na próg CRITICAL (`failOnCVSS 9`), więc finding HIGH 7.5 jest wykryty i raportowany, ale **nie blokuje** PR. Krytyczny element narracji H2 — udowadnia że bramka respektuje politykę severity zamiast zawsze padać.

**Asymetria narzędzi (B V3 obserwacja)**: Trivy wykrył 3 CVE w gunicorn 20.0.0 (CVE-2024-1135, CVE-2024-6827, CVE-2026-27205), Dep-Check 0 findings dla tego pakietu. Sugeruje że Dep-Check ma słabsze pokrycie ekosystemu Python — wartościowy materiał dla rozdz. 5 (argument za defense-in-depth).

### Scenariusz C — Dockerfile

| Wariant | Charakterystyka | Wykrycia | Status |
|---------|-----------------|----------|--------|
| 1 | 4 błędy razem (latest + brak USER + brak HEALTHCHECK + apt-get bez pin) | Hadolint DL3007 + Checkov CKV_DOCKER_2/3/7 + Trivy image CVE | ✅ 5/5 (faza 1) |
| 2 | **Tylko brak USER** (reszta poprawna) | **1 finding**: Checkov CKV_DOCKER_3 (pure izolacja) | ✅ 3/3 (faza 2) |
| 3 | **Brak HEALTHCHECK + ADD zamiast COPY** | **5 findings**: Checkov CKV_DOCKER_2 + 2×CKV_DOCKER_4 (ADD), Hadolint 2×DL3020 (ADD) | ✅ 3/3 (faza 2) |

**Korekta planu V3** — pierwotnie planowano DL3008 (apt-get bez pin), ale to reguła `IGNORED` w `configs/.hadolint.yaml`. Zastąpione brakiem HEALTHCHECK + ADD, co daje 5 findings rozłożone na 2 narzędzia (Checkov CKV_DOCKER_4 dla ADD oraz Hadolint DL3020 dla ADD — **defense-in-depth** w działaniu).

V2 testuje **ziarnistość** (1 reguła, 1 finding, bramka blokuje). V3 testuje **cross-tool redundancję** (2 narzędzia niezależnie detektują ten sam pattern ADD).

### Scenariusz D — DAST

| Wariant | Konfiguracja ZAP | Co testuje | Status |
|---------|------------------|------------|--------|
| 1 | `zap-full-scan` bez autentykacji | publiczne endpointy Juice Shop | ✅ 5/5 (faza 1) — 16 alertów × 5 runów (100% determinizm) |
| ~~2~~ | ~~Authenticated scan~~ | endpointy autoryzowane | **POMINIĘTY** |
| ~~3~~ | ~~Aggressive AJAX + fuzzing~~ | głębsze ścieżki | **POMINIĘTY** |

**Wariant 2 (authenticated) pominięty** — pierwotnie planowane, ale w trakcie fazy 2 podjęto decyzję pragmatyczną: implementacja autoryzowanego skanu ZAP wymagała modyfikacji workflow YAML (pre-auth login + JWT injection do ZAP replacer config), co przy korzyściach marginalnych względem już udowodnionej tezy H4 (V1: 16 alertów × 5 runów, 100% determinizm) nie miało dobrego ROI. Decyzja opisana w rozdz. 4 jako świadome ograniczenie.

**Wariant 3 (aggressive AJAX) pominięty** — agresywny AJAX spider (`-T 30 -m 10`) wprowadziłby ryzyko niedeterminizmu czasowego, sprzeczne z główną tezą o powtarzalności.

## Konwencja nazewnictwa

Dla zachowania spójności z pierwszą fazą:

- **Gałęzie:** `scenario-<a|b|c|d>-variant-<2|3>-run-<N>` (np. `scenario-a-variant-2-run-1`)
- **Foldery screenów:** `docs/screenshots/scenario-<x>/variant-<2|3>/run-<N>/`
- **Foldery SARIF:** `data/raw/scenario-<x>/variant-<2|3>/run-<N>/`
- **Skrypty:** `scripts/scenario_<x>_variant_<N>_{start,finish}.sh` (kopie istniejących z modyfikacją payloadu)

Alternatywnie można rozszerzyć istniejące skrypty o argument `--variant <N>` — zalecane dla DRY, ale wymaga większego refaktoru.

## Faktyczny czas wykonania fazy 2

Eksperyment fazy 2 wykonany 2026-06-13 w jednej sesji ~4 h.

| Scenariusz | Czas pojedynczego runa | Warianty × runs | Czas CI łączny |
|------------|------------------------|------------------|----------------|
| A | ~25 s (blok Etap 1) | 1 × 3 = 3 | ~75 s |
| B V2 | ~2 min (blok Etap 3) | 1 × 3 = 3 | ~6 min |
| B V3 | ~14 min (pełny pipeline — kontrola negatywna) | 1 × 3 = 3 | ~42 min |
| C V2 | ~5 min (blok Etap 4) | 1 × 3 = 3 | ~15 min |
| C V3 | ~5 min (blok Etap 4) | 1 × 3 = 3 | ~15 min |
| **Razem** | — | **15 runów** | **~80 min CI** |

Screeny: 15 × 4 = **60 zrzutów ekranu** (run-1 wariantu A i runs ≥ 2 ze auto-copy 01).

## Krok zerowy w nowej sesji

1. **Odczytaj `CLAUDE.md`** — zawiera kontekst i status.
2. **Sprawdź stan PR #37** — zmergowany (`5c56c8c`), faza 1 zamknięta.
3. **Rozszerz workflow** o `actions/upload-artifact@v4` dla Trivy / Hadolint / Checkov SARIF — przed pierwszym runem fazy 2 (poprawia granularność danych).
4. **Zacznij od scenariusza A wariant 2** (najszybszy: ~5 min CI). Wariant: GitHub PAT w `apps/flask-app/.env.example`.
5. **Skopiuj odpowiedni skrypt z fazy 1** i zmodyfikuj payload zgodnie z planem powyżej (konwencja `scripts/scenario_<x>_variant_<N>_{start,finish}.sh`).
6. **Po każdym scenariuszu** — analogiczny PR jak w fazie 1 (`docs/scenario-<x>-variant-<N>-results`).

## Co dalej po wariantach (krok 2)

Po zakończeniu wszystkich wariantów (40 runów dodatkowych):

1. **Aktualizacja `docs/scenario-*.md`** — dodanie tabel wyników dla wariantów 2 i 3.
2. **Zbiorczy artefakt analityczny** — np. `data/results.csv` agregujący wszystkie 60 runów (20 + 40) z metrykami.
3. **Rozdział 4** — opis wykonania eksperymentu (wszystkie scenariusze + warianty, ze zrzutami ekranu).
4. **Rozdział 5** — analiza wyników, weryfikacja hipotez H1-H4, dyskusja.
5. **Wstęp + zakończenie** pracy magisterskiej.

## Rozstrzygnięcia metodologiczne

Rozstrzygnięte w sesji 2026-06-13 — wartości w tabelach wariantów (sekcje wyżej) odzwierciedlają już te decyzje.

### 1. Severity wariantów B 2/3 — mieszane (CRITICAL + kontrola negatywna)

V2 = Pillow 8.0.0 (CVSS 9.1, CRITICAL — inna klasa błędu niż V1). V3 = gunicorn 20.0.0 (CVSS 7.5, HIGH — **bramka świadomie NIE blokuje**). Daje matrycę 2×2 (severity × wynik bramki), zamiast monotonicznego „znowu zablokowane". Bez kontroli negatywnej H2 byłaby słabiej weryfikowalna (brak rozróżnienia „bramka działa" od „bramka jest paranoiczna").

### 2. Warianty C — izolacja vs alternatywny zestaw

V2 = tylko brak `USER` (izolowany Checkov CKV_DOCKER_3 — ziarnistość bramki). V3 = `ADD` + `curl | bash` (Hadolint DL3020/DL3008 — inny zestaw reguł). Trzy ortogonalne wymiary detekcji w obrębie scenariusza.

### 3. DAST — tylko V2 (authenticated), V3 pominięty

Powtarzanie deterministycznego skanu daje ~0 nowej informacji. Authenticated scan istotnie zmienia powierzchnię. Agresywny AJAX (V3) wprowadziłby niedeterminizm czasowy — sprzeczne z H4.

### 4. Konwencja gałęzi — pełna forma

`scenario-a-variant-2-run-1` (spójna z konwencją folderów `docs/screenshots/scenario-x/variant-N/run-N/`). 23 znaki są akceptowalne; reprodukowalność > zwięzłość.

### 5. Refaktor skryptów — kopiowanie

Skrypty fazy 1 to zamrożone artefakty eksperymentu — refaktor parametryzowany ryzykuje subtelnym bugiem psującym reprodukowalność. Konwencja: `scenario_<x>_variant_<N>_{start,finish}.sh`.

## Znane luki w danych fazy 1 (do uzupełnienia w fazie 2)

Walidacja parsera `analyze_results.py` na 20 runach fazy 1 ujawniła dwie luki w archiwizacji artefaktów. Nie wpływają na poprawność samego eksperymentu (pipeline biegał poprawnie), ale ograniczają granularność danych do rozdz. 5:

1. **Trivy / Hadolint / Checkov nie były archiwizowane lokalnie** — SARIF tych narzędzi trafiał tylko do GHAS Code Scanning. Do fazy 2 dodać kroki `actions/upload-artifact@v4` dla `trivy-fs.sarif`, `trivy-image.sarif`, `hadolint.sarif`, `checkov-results.sarif` w workflow.
2. **ZAP-baseline-report brak w scenariuszu C run-1 i run-3** — pipeline biegał, ale artefakt nie został pobrany lokalnie. W fazie 2 weryfikować obecność wszystkich folderów po każdym runie (lista kontrolna w skrypcie `*_finish.sh`).

Dla fazy 1 — przy potrzebie pełnej granularności rozdz. 5 — można uzupełnić dane przez `gh api` (Code Scanning Alerts), ale tylko gdy okaże się niezbędne dla weryfikacji H1-H4.
