# Scenariusz D — DAST na OWASP Juice Shop

**Mapowanie zagrożeń:** A03:2021 „Injection" (SQL Injection), A07:2021 „Cross-Site Scripting", STRIDE — Tampering
**Testowane narzędzie:** OWASP ZAP (full active scan)

## Charakterystyka scenariusza

W odróżnieniu od scenariuszy A, B oraz C scenariusz D nie wymaga wprowadzania nowych podatności do kodu — wykorzystuje istniejące, udokumentowane podatności OWASP Juice Shop. Kluczowymi celami skanowania są:

- klasyczna podatność SQL Injection w formularzu logowania (`POST /rest/user/login`) — kanoniczne wstrzyknięcie `' OR 1=1 --`,
- reflected XSS w wyszukiwarce produktów (`GET /#/search?q=...`),
- szereg dodatkowych podatności indeksowanych w katalogu OWASP Juice Shop CTF.

## Procedura

W ramach scenariusza:

1. Workflow CI uruchamia kontener `bkimminich/juice-shop` w wewnętrznej sieci Docker.
2. Po osiągnięciu stanu gotowości (zwracanego przez healthcheck Juice Shop) uruchamiany jest kontener `zaproxy/zap-stable` w trybie `zap-full-scan.py`.
3. Wyniki publikowane są jako raport SARIF + raport HTML jako artefakt workflow.

## Oczekiwany rezultat

OWASP ZAP wykrywa co najmniej:
- alert wysokiego severity dla SQL Injection w endpoincie logowania,
- alert wysokiego lub średniego severity dla reflected XSS,
- kilka–kilkanaście alertów średniego severity dla nagłówków bezpieczeństwa (CSP, HSTS, X-Frame-Options).

Bramka bezpieczeństwa konfiguruje próg `--exit-code` na poziomie alertów wysokiego severity, dzięki czemu scenariusz w sposób deterministyczny prowadzi do zatrzymania potoku.

## Wyniki pięciu powtórzeń

_Tabela zostanie uzupełniona po wykonaniu eksperymentu._
