# Scenariusz A — Wyciek sekretów

**Mapowanie zagrożeń:** CICD-SEC-6 „Insufficient Credential Hygiene", STRIDE — Information Disclosure
**Testowane narzędzia:** Gitleaks (pre-commit + CI)

## Opis modyfikacji

W pliku `apps/flask-app/config.py` (utworzonym wyłącznie na potrzeby scenariusza) umieszczany jest fałszywy klucz AWS Access Key ID o syntaktycznie poprawnym, lecz nieaktywnym formacie `AKIA[A-Z0-9]{16}`. Klucz nie jest powiązany z żadnym realnym kontem AWS.

## Oczekiwany rezultat

1. **Pre-commit hook Gitleaks** blokuje commit lokalnie z exit code ≠ 0.
2. W przypadku obejścia hooka (`git commit --no-verify`), job `secrets-scan` w workflow CI wykrywa sekret w historii commitów, oznacza job jako `failure` i blokuje merge pull requesta dzięki ochronie gałęzi `main`.

## Procedura

```bash
git checkout -b scenario-a-run-N
# wprowadź zmianę: utwórz config.py z kluczem AKIA...
git add apps/flask-app/config.py
git commit --no-verify -m "scenario A: introduce fake AWS key"
git push -u origin scenario-a-run-N
gh pr create --title "Scenario A run N" --body "Experiment scenario A"
# zarejestruj zrzuty ekranu i pobierz artefakty
gh run download <run-id> -D data/raw/scenario-a/run-N/
gh pr close scenario-a-run-N --delete-branch
```

## Wyniki pięciu powtórzeń

_Tabela zostanie uzupełniona po wykonaniu eksperymentu._

| Powtórzenie | Pre-commit | CI secrets-scan | True Positive | False Positive | Czas wykrycia [s] |
|-------------|------------|-----------------|---------------|----------------|-------------------|
| 1 | ? | ? | ? | ? | ? |
| 2 | ? | ? | ? | ? | ? |
| 3 | ? | ? | ? | ? | ? |
| 4 | ? | ? | ? | ? | ? |
| 5 | ? | ? | ? | ? | ? |
