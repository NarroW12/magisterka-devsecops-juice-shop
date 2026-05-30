# Zrzuty ekranu eksperymentu

## Konwencja nazewnictwa

Każdy plik PNG umieszczany jest w katalogu `<scenariusz>/run-<N>/` i nazwany według wzorca:

```
NN-krotki-opis.png
```

gdzie `NN` to dwucyfrowy numer porządkowy w danym uruchomieniu.

## Wymagania techniczne

- Format: **PNG** (nie JPG — kompresja stratna gubi szczegóły tekstu w terminalu i logach).
- Tryb: jasny lub ciemny — byle spójnie w obrębie jednego scenariusza.
- Rozdzielczość: oryginalna (bez skalowania), powiększenie tekstu opcjonalne dla czytelności.
- Bez wrażliwych danych poza eksperymentem (nie pokazuj innych zakładek przeglądarki, e-maili itp.).

## Skróty klawiszowe macOS

- `Cmd+Shift+4` → zaznaczenie obszaru, zapis do `~/Desktop`.
- `Cmd+Shift+4`, potem `Spacja` → zrzut całego okna (z cieniem).
- `Cmd+Shift+5` → narzędzie do zrzutów (więcej opcji).

## Wzorzec dla każdego scenariusza

| Numer | Co zawiera | Skąd |
|-------|-----------|------|
| `01-precommit-blocked.png` | Terminal — pre-commit Gitleaks blokuje commit | Terminal lokalny |
| `02-pr-blocked.png` | Strona PR z czerwonym ✗ przy bramce | GitHub web UI |
| `03-security-tab.png` | Zakładka Security → Code Scanning z alertem | GitHub web UI |
| `04-ci-log.png` | Log konkretnego joba pokazujący przyczynę zablokowania | GitHub Actions |

Dla scenariusza D (DAST) zamiast `01-precommit-blocked.png` używamy `01-zap-scan-running.png`, ponieważ DAST nie ma warstwy pre-commit.
