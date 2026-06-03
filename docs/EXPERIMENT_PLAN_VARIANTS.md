# Plan rozszerzenia eksperymentu — warianty

> **Charakter dokumentu:** Niniejszy plan opisuje **rozszerzenie (dodatek) do
> głównego eksperymentu**, którego pierwsza faza została już w pełni
> zrealizowana, udokumentowana i zmergowana na gałąź `main`. Faza 1 sama
> w sobie stanowi **kompletny i samodzielnie wystarczający** materiał
> badawczy do opisania w rozdziałach 4 i 5 pracy magisterskiej —
> potwierdza wszystkie cztery hipotezy szczegółowe (H1–H4) i dostarcza
> bogatego zbioru danych (20 runów, 80 zrzutów ekranu, 20 raportów SARIF
> oraz pełne raporty ZAP).
>
> **Cel fazy 2 (rozszerzenia):** wzmocnienie ważności zewnętrznej wyników
> poprzez wykazanie, że narzędzia są skuteczne nie tylko w jednym
> konkretnym wariancie podatności na scenariusz, lecz w całej **klasie
> podobnych podatności**. Jest to bezpośrednia odpowiedź na potencjalne
> pytanie komisji: *„czemu pięć razy uruchomiliście to samo?"*.
>
> **Praktyczna konsekwencja:** wyniki obu faz powinny być następnie
> **wspólnie** opisane i przeanalizowane w rozdziałach 4 i 5 pracy
> — faza 2 nie jest osobnym eksperymentem, lecz uzupełnieniem tej samej
> linii badawczej, dodającym wariancję wprowadzanych podatności przy
> zachowanej stałej konfiguracji narzędzi, środowiska i metryk.

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

Po każdym scenariuszu (A, B, C, D) — dodanie **dwóch nowych wariantów** z różnymi typami podatności/konfiguracji. Każdy wariant po **5 runów** (zgodnie z konwencją pierwszej fazy).

**Łącznie do wykonania:** 4 scenariusze × 2 warianty × 5 runów = **40 nowych runów**.

## Plan szczegółowy — warianty per scenariusz

### Scenariusz A — wyciek sekretów

| Wariant | Typ sekretu | Konkretny payload | Plik | Spodziewana Gitleaks rule |
|---------|------------|--------------------|------|---------------------------|
| 1 | AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` + secret | `apps/flask-app/config.py` | `aws-access-token`, `experiment-aws-access-key-id` |
| **2 (TODO)** | **GitHub Personal Access Token** | `ghp_aBcDeF1234567890abcdef1234567890abcd` (40 znaków po `ghp_`) | `apps/flask-app/.env.example` | `github-pat`, `github-fine-grained-pat` |
| **3 (TODO)** | **Klucz prywatny RSA** | `-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA...\n-----END RSA PRIVATE KEY-----` (przykładowy, nieaktywny) | `apps/flask-app/keys/id_rsa.example` | `private-key` |

Wariant 2 i 3 testują różne klasy reguł Gitleaks (oprócz AWS) — szersza walidacja detektora.

### Scenariusz B — podatna biblioteka

| Wariant | Biblioteka + wersja | CVE | CVSS | Klasa podatności |
|---------|---------------------|-----|------|-----------------|
| 1 | PyYAML 5.3.1 | CVE-2020-14343 | 9.8 CRITICAL | Improper Input Validation (RCE) |
| **2 (TODO)** | **urllib3 1.25.8** | CVE-2020-26137 | 6.5 MEDIUM | CRLF injection w `Host` header — *uwaga: poniżej progu CRITICAL, do dostrojenia* |
| **3 (TODO)** | **cryptography 2.9.2** | CVE-2020-25659 | 5.9 MEDIUM | Bleichenbacher timing oracle — *również poniżej progu, do dostrojenia* |

**Uwaga metodologiczna:** wariant 2 i 3 mają CVSS poniżej progu bramki CRITICAL (≥ 9.0) — należy albo:
- (a) zmienić bibliotekę na taką z CRITICAL (np. Pillow 8.1.0 → CVE-2021-25287 CVSS 9.1),
- (b) świadomie wybrać MEDIUM żeby pokazać że bramka NIE blokuje (informacyjny wynik),
- (c) tymczasowo zmienić próg bramki dla tych wariantów.

Decyzję podjąć w nowej sesji po sprawdzeniu aktualnych baz CVE.

**Alternatywne kandydatki z CRITICAL CVE:**
- `Pillow==8.0.0` (CVE-2021-25287, CVSS 9.1)
- `lxml==4.6.2` (CVE-2021-43818, CVSS 7.5)
- `paramiko==2.4.0` (CVE-2018-7750, CVSS 9.8)
- `gunicorn==20.0.0` (CVE-2024-1135, CVSS 7.5 HIGH)

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
| **2 (TODO)** | **Authenticated scan** (login `admin@juice-sh.op:admin123`) — wymaga konfiguracji ZAP context | endpointy autoryzowane (zwiększona pojemność detekcji) |
| **3 (TODO)** | **Scan z dłuższym AJAX spider** (`-T 30 -m 10`) oraz włączonym fuzzingiem parametrów | bardziej zaawansowane podatności (SQLi, XSS w głębszych ścieżkach) |

**Uwaga implementacyjna:** wariant 2 i 3 wymagają zmiany konfiguracji w workflow YAML i/lub w `configs/.zap/rules.tsv`. To rozszerzenie infrastruktury — może warto zostawić jako wariant 2 (autentykacja) i ewentualnie pominąć wariant 3, lub odwrotnie.

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
| D | ~15 min | 2 × 5 = 10 | ~2 h 30 min (dominuje DAST) |
| **Razem** | — | **40 runów** | **~3 h 47 min czystego CI** |

Plus narzut na screeny (40 × 4 = **160 zrzutów ekranu** × ~30 s = ~80 min ręcznej pracy).

**Total: ~5-6 h pracy w jednej sesji** lub rozłożone na 2-3 sesje.

## Krok zerowy w nowej sesji

1. **Odczytaj `CLAUDE.md`** — zawiera kontekst i status.
2. **Sprawdź stan PR #37** (`gh pr view 37`) — czy zmergowany na main; jeśli nie, najpierw merge.
3. **Wybierz pierwszy wariant do realizacji** — propozycja: scenariusz A wariant 2 (najszybszy: ~5 min CI).
4. **Zdecyduj o dwóch otwartych pytaniach metodologicznych:**
   - Czy używamy CVE poniżej progu CRITICAL w scenariuszu B (warianty 2/3)? Jakich konkretnie?
   - Czy w scenariuszu D wprowadzamy autentykację ZAP (więcej setupu) czy zostawiamy 1 wariant?
5. **Skopiuj odpowiedni skrypt z pierwszej fazy** i zmodyfikuj payload zgodnie z planem powyżej.
6. **Po każdym scenariuszu** — analogiczny PR jak w pierwszej fazie (`docs/scenario-<x>-variant-<N>-results`).

## Co dalej po wariantach (krok 2)

Po zakończeniu wszystkich wariantów (40 runów dodatkowych):

1. **Aktualizacja `docs/scenario-*.md`** — dodanie tabel wyników dla wariantów 2 i 3.
2. **Zbiorczy artefakt analityczny** — np. `data/results.csv` agregujący wszystkie 60 runów (20 + 40) z metrykami.
3. **Rozdział 4** — opis wykonania eksperymentu (wszystkie scenariusze + warianty, ze zrzutami ekranu).
4. **Rozdział 5** — analiza wyników, weryfikacja hipotez H1-H4, dyskusja.
5. **Wstęp + zakończenie** pracy magisterskiej.

## Otwarte pytania metodologiczne

1. **Dla wariantów B 2/3** — preferujemy CVE CRITICAL (żeby pokazać bramkę zawsze blokuje) czy MEDIUM (żeby pokazać że bramka świadomie ignoruje średnie ryzyko)?
2. **Dla wariantów C 2/3** — testujemy izolowane reguły (jedna na raz) czy mieszane zestawy?
3. **Dla wariantów D 2/3** — czy zostawiamy tylko 1 wariant DAST (skoro Juice Shop deterministyczny)?
4. **Konwencja gałęzi** — czy `scenario-a-variant-2-run-1` (długo), czy `scenario-a-v2-r1` (zwięźle)?
5. **Refaktor skryptów** — kopiować czy dodawać argument `--variant`?

Decyzje do podjęcia w nowej sesji.
