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
