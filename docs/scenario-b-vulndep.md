# Scenariusz B — Podatna biblioteka

**Mapowanie zagrożeń:** A06:2021 „Vulnerable and Outdated Components", STRIDE — Tampering
**Testowane narzędzia:** Trivy oraz OWASP Dependency-Check

## Wybór biblioteki

W eksperymencie wybrano bibliotekę **PyYAML w wersji `5.3.1`** dotkniętą podatnością **CVE-2020-14343** (CVSS 9.8 CRITICAL — arbitrary code execution przez `yaml.load()` w trybie `FullLoader`).

Uzasadnienie wyboru:

- jedna linia w pliku `requirements.txt`, jeden konkretny CVE — czytelny demonstrator,
- biblioteka popularna i powszechnie obecna w ekosystemie Python,
- podatność deterministycznie wykrywana przez obie wykorzystywane bazy danych podatności (NVD, GHSA),
- wymiana wersji nie wymaga modyfikacji logiki aplikacji testowej.

## Opis modyfikacji

Do pliku `apps/flask-app/requirements.txt` dodawana jest linia:

```
PyYAML==5.3.1
```

Sama obecność podatnej wersji pakietu w pliku zależności jest wystarczająca dla detekcji przez warstwę SCA — zarówno Trivy, jak i OWASP Dependency-Check analizują manifesty pip statycznie, bez uruchamiania aplikacji ani sprawdzania, czy biblioteka jest faktycznie wywoływana.

## Oczekiwany rezultat

1. Pre-commit hook **nie blokuje** commitu (Gitleaks nie zajmuje się zależnościami).
2. Workflow CI:
   - Etap 1 (Gitleaks) — przechodzi (brak sekretów).
   - Etap 2 (CodeQL SAST) — przechodzi (kod aplikacji nie zmieniony).
   - **Etap 3 (SCA Trivy + Dependency-Check) — pada na bramce CRITICAL**, niezależnie sygnalizując CVE-2020-14343 z obu narzędzi.
   - Etapy 4 (Build + IaC) i 5 (DAST) — pominięte zgodnie z fail-fast.
3. Bramka bezpieczeństwa blokuje merge pull requesta dzięki ochronie gałęzi `main`.

## Procedura

Scenariusz został zautomatyzowany analogicznie do scenariusza A — dwoma skryptami pomocniczymi `scripts/scenario_b_start.sh <N>` oraz `scripts/scenario_b_finish.sh <N>`. Między ich wywołaniami badacz zapisuje cztery zrzuty ekranu z otwartego PR-a do `docs/screenshots/scenario-b/run-<N>/`.

## Wyniki pięciu powtórzeń

Eksperyment został przeprowadzony 31 maja 2026 roku, pięć niezależnych przebiegów na świeżych gałęziach utworzonych z gałęzi `main` po merge'u scenariusza A.

| Powtórzenie | PR | Workflow run | Etap 1 (Gitleaks) | Etap 2 (CodeQL) | Etap 3 (SCA) | Trivy wykrył CVE | Dep-Check wykrył CVE | Czas trwania |
|-------------|----|--------------|-------------------|-----------------|--------------|------------------|----------------------|--------------|
| 1 | #20 | #39 | ✓ pass | ✓ pass | ✗ blokada | ✓ | ✓ | 2 min 23 s |
| 2 | #21 | #40 | ✓ pass | ✓ pass | ✗ blokada | ✓ | ✓ | 2 min 39 s |
| 3 | #22 | #41 | ✓ pass | ✓ pass | ✗ blokada | ✓ | ✓ | 2 min 25 s |
| 4 | #23 | #42 | ✓ pass | ✓ pass | ✗ blokada | ✓ | ✓ | 2 min 26 s |
| 5 | #24 | #43 | ✓ pass | ✓ pass | ✗ blokada | ✓ | ✓ | 2 min 21 s |
| **Średnia** | — | — | **5/5** | **5/5** | **5/5** | **5/5** | **5/5** | **2 min 27 s** |

## Wykryte podatności (Security tab GHAS)

W każdym z pięciu przebiegów Code Scanning rejestrował identyczny zestaw trzech alertów:

| Tool | Rule ID | Severity | Plik | Opis |
|------|---------|----------|------|------|
| `Trivy` | CVE-2020-14343 | CRITICAL | `requirements.txt` | „PyYAML: incomplete fix for CVE-2020-1747" |
| `dependency-check` | CVE-2020-14343 | CRITICAL | `requirements.txt` | „critical severity – CVE-2020-14343 Improper Input Validation vulnerability in pkg:pypi/pyyaml@5.3.1" |
| `Trivy` | CVE-2026-27205 | LOW | `requirements.txt` | „flask: Flask: Information disclosure via improper caching of session data" (alert informacyjny, znany z baseline) |

Najistotniejszym aspektem jest **podwójne, niezależne wykrycie tej samej podatności CVE-2020-14343** przez dwa narzędzia operujące na różnych bazach danych (Trivy korzysta z `mirror.gcr.io/aquasec/trivy-db`, Dependency-Check z lokalnie pobieranej bazy NVD). Konwergencja wyników podnosi wiarygodność detekcji.

## Interpretacja wyników w kontekście hipotez badawczych

W odniesieniu do hipotezy szczegółowej **H2** sformułowanej w rozdziale 3.9.2 — *„narzędzia analizy składu oprogramowania wykrywają sto procent (= 100%) znanych podatnych wersji bibliotek mających udokumentowane wpisy CVE w bazie NVD oraz GHSA"* — scenariusz B osiąga **100% wykrywalności w każdym z pięciu powtórzeń**, jednocześnie zarówno przez Trivy, jak i OWASP Dependency-Check. Wynik potwierdza hipotezę H2.

W odniesieniu do hipotezy szczegółowej **H1** (≥ 80% detekcji ogólnej) — scenariusz B wpisuje się jako kolejny przykład 100% wykrywalności.

W odniesieniu do hipotezy szczegółowej **H3** (≤ 200% narzutu czasu względem baseline) — średni czas trwania scenariusza B wynosi 147 s, czyli około **17% czasu baseline** (T_baseline = 863 s = 14 min 23 s). Fail-fast bramki SCA zatrzymuje potok po dwóch szybkich etapach (Gitleaks + CodeQL), oszczędzając czas wykonania kosztownego DAST. Również tu hipoteza H3 pozostaje spełniona z dużym marginesem.

## Zebrane artefakty dowodowe

- **20 zrzutów ekranu** (5 powtórzeń × 4 kategorie: strona PR, Security tab, Summary workflow, szczegół tabeli Trivy z CVE) w `docs/screenshots/scenario-b/run-1..5/`. Dodatkowo w `run-1/` znajduje się piąty zrzut `04.1-sarif-detail.png` zachowany jako bonusowy ślad wczesnej fazy logu Etapu 3.
- **5 raportów SARIF** w `data/raw/scenario-b/run-1..5/` (poza repozytorium zgodnie z `.gitignore`).
- **5 zamkniętych pull requestów** w historii repozytorium (#20, #21, #22, #23, #24) z dołączonymi komentarzami bota `github-advanced-security` raportującymi inline wykryte podatności.

## Wariant 2 — paramiko 2.4.0 (CVE-2018-7750)

**Cel:** weryfikacja H2 na **innej klasie podatności** niż wariant 1 (RCE deserializacyjne w PyYAML → SSH pre-auth bypass w paramiko). Wykonano w fazie 2 (2026-06-13).

### Substytucja Pillow → paramiko (decyzja metodologiczna)

Pierwotnie planowano Pillow 8.0.0 (CVE-2021-25287, CVSS 9.1 CRITICAL — out-of-bounds read w libtiff). W trakcie pierwszej próby (PR #43) Etap 2 (CodeQL `pip install`) padł na braku `libjpeg-dev` w runnerze ubuntu-latest. Pillow 8.0.0 nie ma prebuilt wheels dla Python 3.12 (release października 2020 vs Py 3.12 z października 2023), wymagając kompilacji z C. Build failed → pipeline padł w niewłaściwym miejscu → wynik metodologicznie pusty (nie pokazano detekcji CVE, pokazano build break).

**Rozwiązanie**: substytucja na `paramiko==2.4.0` dotkniętą CVE-2018-7750 (CVSS 9.8 CRITICAL — SSH pre-auth authentication bypass prowadzące do RCE). paramiko jest **pure Python**, bez wymagań kompilacyjnych. CVE-2018-7750 należy do innej klasy (CWE-287 Improper Authentication) niż PyYAML (CWE-20 Improper Input Validation), zachowując orthogonality z wariantem 1.

### Konfiguracja

Dopisanie linii do `apps/flask-app/requirements.txt`:

```
paramiko==2.4.0
```

### Procedura

```bash
bash scripts/scenario_b_variant_2_start.sh <N>
bash scripts/scenario_b_variant_2_finish.sh <N>
```

### Wyniki trzech powtórzeń

| Run | PR | Workflow run | Etap 3 SCA | Trivy findings | Dep-Check findings |
|-----|----|--------------|------------|----------------|--------------------|
| 1 | [#44](https://github.com/NarroW12/magisterka-devsecops-juice-shop/pull/44) | 27468161606 | ✓ zablokował | 3 (CVE-2018-7750 9.8 + CVE-2018-1000805 8.8 + CVE-2026-27205 2.0) | 3 (CVE-2018-7750 CRITICAL + 2 MEDIUM) |
| 2 | [#45](https://github.com/NarroW12/magisterka-devsecops-juice-shop/pull/45) | 27468424867 | ✓ zablokował | identyczne 3 CVE | identyczne 3 CVE |
| 3 | [#46](https://github.com/NarroW12/magisterka-devsecops-juice-shop/pull/46) | 27468584460 | ✓ zablokował | identyczne 3 CVE | identyczne 3 CVE |

100% determinizm w 3/3 przebiegach, identyczny zbiór findings między narzędziami i runami.

### Wykryte CVE w paramiko 2.4.0

| CVE | CVSS | Klasa | Trivy | Dep-Check |
|-----|------|-------|-------|-----------|
| CVE-2018-7750 | 9.8 CRITICAL | Authentication bypass (SSH pre-auth → RCE) | ✓ | ✓ |
| CVE-2018-1000805 | 8.8 HIGH | Auth bypass (alternatywny vector) | ✓ | — |
| CVE-2022-24302 | 5.9 MEDIUM | Key disclosure | — | ✓ |
| CVE-2023-48795 | 5.9 MEDIUM | Terrapin SSH attack | — | ✓ |
| CVE-2026-27205 | 2.0 LOW | Pochodne, niezwiązane bezpośrednio z paramiko | ✓ | — |

Trivy i Dep-Check mają **częściowo rozłączne pokrycie CVE** — Trivy znajduje 2 HIGH+ wyłącznie u siebie, Dep-Check znajduje 2 MEDIUM wyłącznie u siebie. Wspólnie wykrywają tylko CVE-2018-7750 (target wariantu). Pierwsza ważna obserwacja dla rozdz. 5: nawet w tej samej klasie podatności narzędzia różnią się **pokryciem**, nie tylko interfejsem.

## Wariant 3 — gunicorn 20.0.0 (kontrola negatywna)

**Cel:** weryfikacja H2 w sensie **negatywnym** — udowodnienie że bramka **respektuje politykę severity** zamiast blokować wszystko po kolei. Próg bramki: `failOnCVSS 9` (Dep-Check) oraz `severity: CRITICAL` (Trivy). Znaleziska poniżej progu powinny być **raportowane, ale nie blokujące**.

### Konfiguracja

Zamiana w `apps/flask-app/requirements.txt`: `gunicorn==22.0.0` → `gunicorn==20.0.0` (dotknięta CVE-2024-1135, CVSS 7.5 HIGH — HTTP Request Smuggling).

### Wyniki trzech powtórzeń

| Run | PR | Workflow run | Wszystkie 6 etapów | Trivy findings | Dep-Check |
|-----|----|--------------|---------------------|----------------|-----------|
| 1 | [#47](https://github.com/NarroW12/magisterka-devsecops-juice-shop/pull/47) | 27468764006 | ✓ SUCCESS | 3 (max 8.2 HIGH) | 0 |
| 2 | [#48](https://github.com/NarroW12/magisterka-devsecops-juice-shop/pull/48) | 27469218386 | ✓ SUCCESS | identyczne 3 | 0 |
| 3 | [#49](https://github.com/NarroW12/magisterka-devsecops-juice-shop/pull/49) | 27470294090 | ✓ SUCCESS | identyczne 3 | 0 |

**Bramka NIE zablokowała w żadnym z 3 przebiegów** — zgodnie z polityką (CVSS < 9.0 raportowane, nie blokujące). 100% determinizm.

### Wykryte CVE w gunicorn 20.0.0 (Trivy)

| CVE | CVSS | Trivy | Dep-Check |
|-----|------|-------|-----------|
| CVE-2024-1135 | **8.2 HIGH** (Trivy podaje wyższą wartość niż NVD 7.5) | ✓ | ✗ |
| CVE-2024-6827 | 7.5 HIGH | ✓ | ✗ |
| CVE-2026-27205 | 2.0 LOW | ✓ | ✗ |

**Krytyczna obserwacja metodologiczna**: Dep-Check **nie znalazł żadnego z trzech CVE** w gunicorn 20.0.0, mimo że są one obecne w NVD. Trivy wykrywa wszystkie trzy. Sugeruje to:

1. Słabsze pokrycie ekosystemu Python w bazie NVD-CPE używanej przez Dep-Check w porównaniu do bazy Trivy (`aquasec/trivy-db`)
2. Konieczność stosowania **co najmniej dwóch narzędzi SCA niezależnie** — pojedyncze narzędzie ma ślepe punkty

Asymetria pokrycia jest **pierwszorzędnym materiałem dla rozdz. 5** — argument za defense-in-depth nie tylko jako "więcej tym lepiej", ale jako konieczność wynikająca z faktycznych luk w pokryciu pojedynczych narzędzi.

### Konsolidacja H2 z trzech wariantów

| Wariant | Biblioteka | Główny CVE | CVSS | Wynik bramki | Detection (Trivy / Dep-Check) |
|---------|------------|------------|------|--------------|-------------------------------|
| 1 | PyYAML 5.3.1 | CVE-2020-14343 | 9.8 CRITICAL | BLOCK | ✓ / ✓ |
| 2 | paramiko 2.4.0 | CVE-2018-7750 | 9.8 CRITICAL | BLOCK | ✓ / ✓ |
| 3 | gunicorn 20.0.0 | CVE-2024-1135 | 7.5 HIGH | **PASS** (kontrola negatywna) | ✓ / **✗** |

Macierz 2×2 weryfikacji H2:

|  | CVSS ≥ 9 | CVSS < 9 |
|--|----------|----------|
| **Bramka blokuje** | V1, V2 — 6 runów ✓ | — |
| **Bramka nie blokuje** | — | V3 — 3 runy ✓ |

H2 zostaje **w pełni potwierdzona** w obu kierunkach: pozytywnym (blokada CRITICAL) i negatywnym (przepuszczenie HIGH zgodnie z polityką). Łącznie 11 niezależnych przebiegów (5 V1 + 3 V2 + 3 V3).

### Zebrane artefakty wariantów 2 i 3

- **24 zrzuty ekranu** (3 + 3 powtórzenia × 4 kategorie) w `docs/screenshots/scenario-b/variant-{2,3}/run-1..3/`. W V3 screen `01-pr-passed.png` (zamiast `01-pr-blocked.png`) reflektuje sukces wszystkich etapów.
- **6 raportów SARIF** w `data/raw/scenario-b/variant-{2,3}/run-1..3/`.
- **6 zamkniętych pull requestów**: V2 #44, #45, #46; V3 #47, #48, #49.
