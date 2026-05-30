# Notatki projektowe — magisterka DevSecOps

Plik dla utrzymania kontekstu między sesjami Claude Code.

## Konwencje pracy

- Język polski w komitach i komunikacji z użytkownikiem
- Commit messages w formacie conventional commits (po angielsku, body po polsku/angielsku)
- Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com> na końcu każdego commitu robionego przeze mnie
- Email do commitów: `jakub.omie@gmail.com`, name: `NarroW12`
- Nie modyfikować globalnego git config — używać `git -c user.email=... -c user.name=...` per-commit
- Screenshoty: `docs/screenshots/<scenariusz>/run-<N>/NN-opis.png` (PNG, format 01-, 02-, 03-, 04-)

## Architektura repozytorium

- `apps/flask-app/` — aplikacja testowa Python/Flask (baseline)
- `apps/juice-shop/` — docker-compose dla OWASP Juice Shop v17.2.0
- `.github/workflows/security-pipeline.yml` — 6-etapowy potok DevSecOps
- `configs/` — konfiguracja Gitleaks, CodeQL, Hadolint, ZAP
- `docs/scenario-*.md` — dokumentacja każdego scenariusza A/B/C/D
- `data/raw/<scenariusz>/run-<N>/` — surowe artefakty SARIF z każdego przebiegu

## Stałe wartości eksperymentu

- T_baseline = ~14 min 23 s (zarejestrowany 2026-05-10 na run 25630041895)
- Branch model: GitHub Flow (main + krótkie feature branches)
- Branch protection na main: 5 wymaganych statusów (Etap 1-5), strict mode
- Hipotezy H1-H4 zdefiniowane w Rozdziale 3, sekcja 3.9.2
- Scenariusze A/B/C/D opisane w Rozdziale 3, sekcja 3.10

## Znaleziska metodologiczne do rozdziału 4

### Gitleaks-action v2 nie uploaduje SARIF do GHAS Code Scanning

W trakcie scenariusza A run 1 (PR #12) odkryto, że `gitleaks/gitleaks-action@v2`
przy wykryciu sekretu i zwróceniu `exit-code 1`:

- ✅ pozostawia komentarze inline na PR przy konkretnych liniach (przez bota
  `github-actions[bot]` z formatem „Gitleaks has detected a secret with
  rule-id ... in commit ...")
- ✅ generuje annotation w widoku workflow run („Leaks detected, see job summary")
- ✅ zapisuje SARIF jako artefakt workflow (`gitleaks-results.sarif`)
- ❌ NIE uploaduje SARIF do GitHub Advanced Security Code Scanning tab

Skutek: zakładka Security → Code Scanning pozostaje pusta dla danej gałęzi
i PR, mimo że alerty Gitleaks są dostępne w trzech innych kanałach. To znana
limitacja akcji w wariancie open-source dla repozytoriów osobistych.

**Rozwiązanie zastosowane:** refaktor Etapu 1 — własny skrypt pobiera binarkę
Gitleaks v8.18.4, generuje SARIF z `--report-format sarif`, deterministycznie
wrzuca przez `github/codeql-action/upload-sarif@v3`, dopiero potem decyduje
o exit code na podstawie liczby znalezisk.

**Implikacja dydaktyczna do rozdziału 4:** istotne zjawisko — narzędzia
open-source pakowane jako GitHub Actions często mają ograniczenia w upload SARIF
zwłaszcza przy fail-exit. Dla deterministycznego raportowania w GHAS Security
tab często konieczne jest własne wywołanie binarki + explicit upload-sarif.

### Trivy-action wymusza wszystkie poziomy severity w trybie SARIF

W trakcie naprawy Etapu 3 (SCA) okazało się, że `aquasecurity/trivy-action`
w trybie `format: sarif` lub `format: json` nadpisuje `TRIVY_SEVERITY` na
`UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL`, ignorując użytkownikową filtrację. To
powoduje że `exit-code: 1` jest wyzwalany przez znaleziska LOW/MEDIUM mimo
deklarowanej polityki `severity: CRITICAL`.

**Rozwiązanie zastosowane:** rozdzielenie raportowania od bramki — SARIF
informacyjny (`exit-code: 0`, wszystkie poziomy) plus oddzielna bramka
w formacie `table` z faktyczną filtracją severity.

**Implikacja dydaktyczna do rozdziału 4:** typowy „policy enforcement gap"
pomiędzy oczekiwaniami użytkownika a zachowaniem narzędzia. Wymaga starannej
weryfikacji każdej akcji pod kątem ukrytych override'ów.

### OWASP Dependency-Check vs setup-java w Dockerze

Akcja `dependency-check/Dependency-Check_Action@main` działa wewnątrz
kontenera Dockera dostarczającego własną Javę. Gdy w workflow ustawiona jest
host-side `actions/setup-java@v4`, `JAVA_HOME` wskazuje na ścieżkę poza
kontenerem i Dep-Check pada z „JAVA_HOME is not defined correctly".

**Rozwiązanie zastosowane:** usunięcie `setup-java` step + `continue-on-error: true`
na Dep-Check (jest narzędziem komplementarnym względem Trivy, nie blokerem).

### Akcje używające upload-artifact v3 (sunset styczeń 2025)

`zaproxy/action-full-scan@v0.10.0` używała wewnętrznie deprecated
`upload-artifact@v3`, co skutkowało błędem „artifact name is not valid"
pomimo komunikatu „Artifact name is valid!" w logu (typowy ślad starej
api 6.0-preview po sunset).

**Rozwiązanie:** upgrade na `v0.13.0` (zawiera upload-artifact@v4).

## Plan rozdziałów

- Rozdz. 1 ✅ — Ewolucja zagrożeń (`Rozdział_1.md`)
- Rozdz. 2 ✅ — Przegląd narzędzi (`Rozdzial_2.md`)
- Rozdz. 3 ✅ — Projekt środowiska + metodyka (`Rozdzial_3.md`)
- Rozdz. 4 ⏳ — Wykonanie eksperymentu (scenariusze + screeny + wyniki)
- Rozdz. 5 ⏳ — Analiza i dyskusja
- `Metodologia_badan.md` — wcześniejsza wersja, do streszczenia jako materiał
  pomocniczy (decyzja użytkownika: opcja C — przekształcić w skrócony opis)

## Wskazówki dla przyszłych sesji

- Nie używać emoji w plikach bez wyraźnej prośby
- Nie tworzyć dokumentacji `.md` bez prośby
- Pisać opisowo, akapitami; punktory tylko gdy naturalne (zgodnie z preferencją
  użytkownika z rozdziału 2)
- Bibliografia w Harvard, polska literatura uzupełniona: Zalewski (2021),
  Smarż (2022)
- Nie ruszać podsumowań na końcu rozdziałów — będzie jedno zbiorcze na koniec
  pracy
