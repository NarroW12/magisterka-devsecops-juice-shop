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

## Stan eksperymentu (faza 1 zakończona 2026-06-03)

**Faza 1 — pierwsze warianty wszystkich scenariuszy:**

| Scenariusz | Modyfikacja | Runs | Detection | PR |
|------------|-------------|------|-----------|-----|
| A — sekrety | AWS key w `apps/flask-app/config.py` | 5/5 | 100% (3/3 znalezisk Gitleaks) | #14-#18, doc #19 |
| B — podatna biblioteka | PyYAML 5.3.1 (CVE-2020-14343) | 5/5 | 100% (Trivy + Dep-Check) | #20-#24, doc #25 |
| C — Dockerfile | latest + brak USER/HEALTHCHECK + apt | 5/5 | 100% (Hadolint + Checkov + Trivy) | #26-#30, doc #31 |
| D — DAST | Pełny scan Juice Shop bez autentykacji | 5/5 | FAIL:0 / WARN:10 / PASS:132 (100% determinizm) | #32-#36, doc #37 |

- **Wszystkie 4 PR-y dokumentacyjne (#19, #25, #31, #37)** zmergowane do main.
- **20 runów łącznie**, 80 zrzutów ekranu, 20 raportów SARIF/HTML.
- **Hipotezy H1, H2, H3, H4** — wszystkie wstępnie potwierdzone z 100% wynikiem.

**Faza 2 (TODO) — warianty:**

Po pytaniu metodologicznym użytkownika („czemu 5 razy to samo?") podjęto decyzję
o dodaniu nowych wariantów. **35 runów łącznie** (asymetria: 2 warianty dla A/B/C,
1 dla D — uzasadnione metodologicznie, plan w `docs/EXPERIMENT_PLAN_VARIANTS.md`).

Kluczowa decyzja: **scenariusz B-V3 = gunicorn 20.0.0 (HIGH 7.5) jako kontrola
negatywna** — bramka świadomie nie blokuje przy CVSS < 9, co wzmacnia weryfikację H2.

Przed pierwszym runem fazy 2: rozszerzyć workflow o `upload-artifact` dla Trivy /
Hadolint / Checkov SARIF (faza 1 nie archiwizowała ich lokalnie).

## Wskazówki dla nowej sesji rozpoczynającej fazę 2

1. **Najpierw przeczytaj `docs/EXPERIMENT_PLAN_VARIANTS.md`** — pełny plan z otwartymi pytaniami.
2. **Sprawdź stan PR #37** (`gh pr view 37`) — czy zmergowany; jeśli nie, najpierw merge.
3. **Rozstrzygnij 5 otwartych pytań metodologicznych** opisanych na końcu pliku planu.
4. **Zacznij od scenariusza A wariant 2** (najszybszy: 5 min CI per run).
5. **Zachowaj konwencję pierwszej fazy** — screen → finish → PR podsumowujący per scenariusz.

## Wskazówki dla przyszłych sesji

- Nie używać emoji w plikach bez wyraźnej prośby
- Nie tworzyć dokumentacji `.md` bez prośby
- Pisać opisowo, akapitami; punktory tylko gdy naturalne (zgodnie z preferencją
  użytkownika z rozdziału 2)
- Bibliografia w Harvard, polska literatura uzupełniona: Zalewski (2021),
  Smarż (2022)
- Nie ruszać podsumowań na końcu rozdziałów — będzie jedno zbiorcze na koniec
  pracy
