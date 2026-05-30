# Scenariusz A — Wyciek sekretów

**Mapowanie zagrożeń:** CICD-SEC-6 „Insufficient Credential Hygiene", STRIDE — Information Disclosure
**Testowane narzędzia:** Gitleaks (pre-commit + CI)

## Opis modyfikacji

W pliku `apps/flask-app/config.py` (utworzonym wyłącznie na potrzeby scenariusza) umieszczany jest fałszywy klucz AWS Access Key ID o syntaktycznie poprawnym, lecz nieaktywnym formacie `AKIA[A-Z0-9]{16}`, wraz z towarzyszącym mu Secret Access Key. Klucze nie są powiązane z żadnym realnym kontem AWS.

Zawartość pliku:

```python
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

## Oczekiwany rezultat

1. **Pre-commit hook Gitleaks** blokuje commit lokalnie z exit code 1, raportując 3 znaleziska (dwa różne dopasowania reguł dla AWS Access Key ID oraz jedno dla Secret Access Key).
2. Po obejściu hooka flagą `git commit --no-verify`, job `Etap 1 — Skanowanie sekretów (Gitleaks)` w workflow CI:
   - pobiera deterministyczną wersję Gitleaks v8.18.4,
   - generuje raport SARIF,
   - uploaduje SARIF do GitHub Advanced Security Code Scanning,
   - zwraca exit code 1 w kroku „Fail if leaks detected (gate)",
   - blokuje merge pull requesta dzięki ochronie gałęzi `main`.

## Procedura

Scenariusz został zautomatyzowany dwoma skryptami pomocniczymi:

```bash
# Etap 1 — utworzenie gałęzi, modyfikacja, PR, oczekiwanie na workflow
bash scripts/scenario_a_start.sh <N>

# (ręcznie: zrzuty ekranu zapisane w docs/screenshots/scenario-a/run-<N>/)

# Etap 2 — zamknięcie PR, skasowanie gałęzi, powrót na main
bash scripts/scenario_a_finish.sh <N>
```

Pełna procedura ręczna (gdyby uruchamiać bez skryptów) wygląda następująco:

```bash
git checkout main && git pull
git checkout -b scenario-a-run-N
# utwórz apps/flask-app/config.py z fałszywym kluczem AKIA...
git add apps/flask-app/config.py
git commit --no-verify -m "scenario A run N: introduce fake AWS access key"
git push -u origin scenario-a-run-N
gh pr create --base main --head scenario-a-run-N \
  --title "Scenario A run N — wyciek sekretu (fałszywy klucz AWS)" \
  --body "Eksperyment scenariusz A run N"
# poczekaj aż workflow padnie na Etapie 1
gh run download <run-id> -D data/raw/scenario-a/run-N/
gh pr close <pr-number> --delete-branch
```

## Wyniki pięciu powtórzeń

Eksperyment został przeprowadzony 30–31 maja 2026 roku, pięć niezależnych przebiegów na świeżych gałęziach utworzonych z gałęzi `main`.

| Powtórzenie | PR | Workflow run | Pre-commit | CI secrets-scan | True Positive | False Positive | Czas wykrycia [s] |
|-------------|----|--------------|------------|-----------------|---------------|----------------|-------------------|
| 1 | #14 | #32 | ✓ zablokował | ✓ zablokował | 3 | 0 | 24 |
| 2 | #15 | #33 | ✓ zablokował | ✓ zablokował | 3 | 0 | 22 |
| 3 | #16 | #34 | ✓ zablokował | ✓ zablokował | 3 | 0 | 24 |
| 4 | #17 | #35 | ✓ zablokował | ✓ zablokował | 3 | 0 | 22 |
| 5 | #18 | #36 | ✓ zablokował | ✓ zablokował | 3 | 0 | 22 |
| **Średnia** | — | — | **5/5** | **5/5** | **3,0** | **0,0** | **22,8** |

## Wykryte reguły Gitleaks

W każdym z pięciu przebiegów zarejestrowano dokładnie ten sam zestaw trzech znalezisk:

| Rule ID | Lokalizacja | Typ sekretu |
|---------|-------------|-------------|
| `aws-access-token` (reguła domyślna Gitleaks) | `apps/flask-app/config.py:9` | AWS Access Key ID |
| `experiment-aws-access-key-id` (reguła własna) | `apps/flask-app/config.py:9` | AWS Access Key ID |
| `experiment-aws-secret-access-key` (reguła własna) | `apps/flask-app/config.py:10` | AWS Secret Access Key |

Pełne raporty SARIF dla wszystkich pięciu przebiegów dostępne są lokalnie w `data/raw/scenario-a/run-1..5/gitleaks-results.sarif/gitleaks.sarif` (folder objęty `.gitignore` zgodnie z konwencją „raw outside repo, opracowane wyniki w repo").

## Interpretacja wyników w kontekście hipotez badawczych

Z perspektywy hipotezy szczegółowej **H1** sformułowanej w rozdziale 3.9.2 — *„narzędzia statycznej analizy kodu w połączeniu z narzędziami wykrywania sekretów wykrywają co najmniej osiemdziesiąt procent (≥ 80%) celowo wprowadzonych podatności kodowych"* — scenariusz A daje wynik **100% wykrywalności (Detection Rate)** w każdym z pięciu powtórzeń, z zachowaniem **0% współczynnika fałszywych alarmów (False Positive Rate)**.

Z perspektywy hipotezy szczegółowej **H3** dotyczącej wpływu na czas budowania, fail-fast bramki Gitleaks zatrzymał potok średnio po **22,8 sekundy**, czyli **~2,6% czasu baseline** (T_baseline = 14 min 23 s = 863 s). Oznacza to, że wprowadzenie warstwy detekcji sekretów na pierwszym etapie potoku praktycznie nie generuje istotnego narzutu czasowego dla przebiegów na których faktycznie wykryto sekret — wręcz przeciwnie, oszczędza ~94% czasu poprzez wczesne zatrzymanie dalszych etapów.

## Zebrane artefakty dowodowe

- **20 zrzutów ekranu** (5 powtórzeń × 4 kategorie: pre-commit terminal, strona PR, Security tab, log workflow) w `docs/screenshots/scenario-a/run-1..5/`.
- **5 raportów SARIF** w `data/raw/scenario-a/run-1..5/`.
- **5 zamkniętych pull requestów** w historii repozytorium GitHub (#14, #15, #16, #17, #18) z dołączonymi komentarzami bota `github-advanced-security` raportującymi inline znalezione sekrety.
- **Tablica Code Scanning** zachowała alerty z każdego z pięciu przebiegów (filtr `pr:N`).
