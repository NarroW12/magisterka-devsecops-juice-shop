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

Aplikacja Flaska zostaje rozszerzona o niewielki endpoint `POST /import-config` przyjmujący treść YAML, parsowaną przez `yaml.safe_load()` (samo wywołanie jest bezpieczne — celowo, aby nie wykonywać payloadu lokalnie). Sama obecność podatnej wersji pakietu jest jednak wystarczająca dla detekcji przez SCA.

## Oczekiwany rezultat

1. Job `dependency-scan` w workflow CI wykrywa podatność CVSS ≥ 9.0.
2. Bramka bezpieczeństwa SCA blokuje merge pull requesta.
3. Trivy oraz Dependency-Check raportują tę samą podatność CVE-2020-14343 — wynik zostanie zarejestrowany dla porównania skuteczności obu narzędzi.

## Wyniki pięciu powtórzeń

_Tabela zostanie uzupełniona po wykonaniu eksperymentu._
