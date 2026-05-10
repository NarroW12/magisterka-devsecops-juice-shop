# Scenariusz C — Błędy konfiguracji Dockerfile

**Mapowanie zagrożeń:** A05:2021 „Security Misconfiguration", STRIDE — Elevation of Privilege
**Testowane narzędzia:** Hadolint (linting Dockerfile), Checkov (skanowanie konfiguracji), Trivy (skanowanie obrazu)

## Opis modyfikacji

Plik `apps/flask-app/Dockerfile` zostaje zastąpiony wersją zawierającą cztery typowe błędy konfiguracyjne:

1. obraz bazowy oznaczony tagiem `latest` (regulamin Hadolint DL3007),
2. brak instrukcji `USER` — kontener uruchamiany jako root (CKV_DOCKER_8),
3. brak instrukcji `HEALTHCHECK` (DL3057),
4. instalacja pakietów systemowych bez przypiętych wersji (DL3008).

## Oczekiwany rezultat

1. Job `iac-scan` w workflow CI wykrywa wszystkie cztery błędy.
2. Bramka bezpieczeństwa Hadolint blokuje merge pull requesta.
3. Skanowanie zbudowanego obrazu narzędziem Trivy dodatkowo wykrywa potencjalne podatności CVE w warstwie systemu operacyjnego, ze względu na brak determinizmu obrazu `latest`.

## Wyniki pięciu powtórzeń

_Tabela zostanie uzupełniona po wykonaniu eksperymentu._
