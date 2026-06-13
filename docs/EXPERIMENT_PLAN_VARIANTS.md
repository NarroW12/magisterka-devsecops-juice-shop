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

Po każdym scenariuszu (A, B, C, D) — dodanie nowych wariantów z różnymi typami podatności/konfiguracji. Każdy wariant po **5 runów** (zgodnie z konwencją pierwszej fazy).

**Symetria 2 warianty per scenariusz złamana świadomie w scenariuszu D** — uzasadnienie w sekcji „Rozstrzygnięcia metodologiczne" niżej.

**Łącznie do wykonania:** 3 × 2 + 1 × 1 = 7 wariantów × 5 runów = **35 nowych runów**.

## Plan szczegółowy — warianty per scenariusz

### Scenariusz A — wyciek sekretów

| Wariant | Typ sekretu | Konkretny payload | Plik | Spodziewana Gitleaks rule |
|---------|------------|--------------------|------|---------------------------|
| 1 | AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` + secret | `apps/flask-app/config.py` | `aws-access-token`, `experiment-aws-access-key-id` |
| **2 (TODO)** | **GitHub Personal Access Token** | `ghp_aBcDeF1234567890abcdef1234567890abcd` (40 znaków po `ghp_`) | `apps/flask-app/.env.example` | `github-pat`, `github-fine-grained-pat` |
| **3 (TODO)** | **Klucz prywatny RSA** | `-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA...\n-----END RSA PRIVATE KEY-----` (przykładowy, nieaktywny) | `apps/flask-app/keys/id_rsa.example` | `private-key` |

Wariant 2 i 3 testują różne klasy reguł Gitleaks (oprócz AWS) — szersza walidacja detektora.

### Scenariusz B — podatna biblioteka

| Wariant | Biblioteka + wersja | CVE | CVSS | Klasa | Oczekiwany wynik bramki |
|---------|---------------------|-----|------|-------|--------------------------|
| 1 | PyYAML 5.3.1 | CVE-2020-14343 | 9.8 CRITICAL | Improper Input Validation (RCE) | **BLOCK** |
| 2 | **Pillow 8.0.0** | CVE-2021-25287 | 9.1 CRITICAL | Out-of-bounds read (libtiff) | **BLOCK** — inny typ błędu niż V1 |
| 3 | **gunicorn 20.0.0** | CVE-2024-1135 | 7.5 HIGH | HTTP Request Smuggling | **PASS** — kontrola negatywna |

V3 to **świadoma kontrola negatywna**: bramka jest skonfigurowana na próg CRITICAL (`failOnCVSS 9`), więc finding HIGH 7.5 powinien być wykryty i raportowany, ale **nie zablokować** PR. To krytyczny element narracji H2 — udowadnia że bramka respektuje politykę severity zamiast zawsze padać.

### Scenariusz C — Dockerfile

| Wariant | Charakterystyka | Wykrycia oczekiwane |
|---------|-----------------|---------------------|
| 1 | 4 błędy razem (latest + brak USER + brak HEALTHCHECK + apt-get bez pin) | Hadolint DL3007 + Checkov CKV_DOCKER_2/3/7 + Trivy image CVE |
| **2 (TODO)** | **Tylko brak USER** (reszta poprawna: pin tag, HEALTHCHECK, pin apt) | Checkov CKV_DOCKER_3 (izolowany — pokazuje że konkretna reguła sama wystarczy) |
| **3 (TODO)** | **`ADD` zamiast `COPY` + `curl \| bash` anti-pattern** | Hadolint DL3020 (ADD over COPY) + DL3008 + Checkov |

Wariant 2 testuje pojedynczy konkretny błąd — sprawdza ziarnistość bramki. Wariant 3 testuje inny zestaw reguł (ADD/curl).

### Scenariusz D — DAST

Aplikacja Juice Shop jest deterministyczna i nie wymaga modyfikacji kodu. Warianty dotyczą **konfiguracji skanu ZAP**:

| Wariant | Konfiguracja ZAP | Co dodatkowo testuje |
|---------|------------------|----------------------|
| 1 | `zap-full-scan` bez autentykacji | publiczne endpointy Juice Shop |
| 2 | **Authenticated scan** (login `admin@juice-sh.op:admin123`) — wymaga konfiguracji ZAP context | endpointy autoryzowane (zwiększona pojemność detekcji) |
| ~~3~~ | ~~Scan z dłuższym AJAX spider + fuzzing~~ | **POMINIĘTY** — uzasadnienie poniżej |

**Wariant 3 pominięty świadomie.** Dodatkowy fuzzing i agresywny AJAX spider (`-T 30 -m 10`) wprowadziłby ryzyko niedeterminizmu czasowego (timeouty zależne od load), co byłoby kontrproduktywne wobec głównej tezy o powtarzalności pipeline'u. Oszczędność: 5 runów × ~15 min = **~75 min CI**. Konsekwencja: asymetryczna liczba wariantów per scenariusz (7 zamiast 8 łącznie) — opisywana w rozdz. 4 jako decyzja metodologiczna.

## Konwencja nazewnictwa

Dla zachowania spójności z pierwszą fazą:

- **Gałęzie:** `scenario-<a|b|c|d>-variant-<2|3>-run-<N>` (np. `scenario-a-variant-2-run-1`)
- **Foldery screenów:** `docs/screenshots/scenario-<x>/variant-<2|3>/run-<N>/`
- **Foldery SARIF:** `data/raw/scenario-<x>/variant-<2|3>/run-<N>/`
- **Skrypty:** `scripts/scenario_<x>_variant_<N>_{start,finish}.sh` (kopie istniejących z modyfikacją payloadu)

Alternatywnie można rozszerzyć istniejące skrypty o argument `--variant <N>` — zalecane dla DRY, ale wymaga większego refaktoru.

## Estymacja czasu

| Scenariusz | Czas pojedynczego runa | Warianty × runs | Czas CI |
|------------|------------------------|------------------|---------|
| A | ~25 s | 2 × 5 = 10 | ~5 min |
| B | ~2 min 30 s | 2 × 5 = 10 | ~25 min |
| C | ~4 min 40 s | 2 × 5 = 10 | ~47 min |
| D | ~15 min | 1 × 5 = 5 | ~1 h 15 min |
| **Razem** | — | **35 runów** | **~2 h 32 min czystego CI** |

Plus narzut na screeny (35 × 4 = **140 zrzutów ekranu** × ~30 s = ~70 min ręcznej pracy).

**Total: ~4-5 h pracy w jednej sesji** lub rozłożone na 2-3 sesje.

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
