# Scenariusz D — DAST na OWASP Juice Shop

**Mapowanie zagrożeń:** A03:2021 „Injection" (SQL Injection), A07:2021 „Cross-Site Scripting", STRIDE — Tampering
**Testowane narzędzie:** OWASP ZAP (full active scan)

## Charakterystyka scenariusza

W odróżnieniu od scenariuszy A, B oraz C scenariusz D nie wymaga wprowadzania nowych podatności do kodu — wykorzystuje istniejące, udokumentowane podatności OWASP Juice Shop. Aplikacja testowa jest deterministycznie kontenerowana (`bkimminich/juice-shop:v17.2.0`), więc kolejne uruchomienia powinny dawać identyczne wyniki, co stanowi szczególnie cenny test powtarzalności narzędzia DAST.

Bramka ZAP w workflow jest skonfigurowana jako **informacyjna** (`fail_action: false`) — DAST nie blokuje workflow, lecz zapisuje pełen raport, który następnie podlega analizie. Decyzja ta odzwierciedla typową praktykę produkcyjną: DAST charakteryzuje się wysokim współczynnikiem fałszywych alarmów i wymaga ręcznej weryfikacji znalezisk, dlatego standardową polityką jest „warn only" zamiast „fail hard".

## Procedura

Trywialna modyfikacja — utworzenie pliku `docs/scenario-d-triggers/run-<N>.md` z informacją o przebiegu — wyzwala pełen workflow CI. Scenariusz zautomatyzowany skryptami `scripts/scenario_d_start.sh <N>` i `scripts/scenario_d_finish.sh <N>`.

## Oczekiwany rezultat

1. Pre-commit hook nie blokuje (brak sekretów).
2. Workflow CI:
   - Etapy 1–4 przechodzą w pełni (brak modyfikacji kodu, zależności ani Dockerfile).
   - **Etap 5 (DAST OWASP ZAP) raportuje znaleziska** w postaci `FAIL-NEW`, `WARN-NEW` i `PASS`, ale dzięki `fail_action: false` job zwraca SUCCESS.
   - Etap 6 (Raportowanie zbiorcze) podsumowuje wszystkie etapy.
3. Cały workflow zwraca SUCCESS — bramka jest informacyjna.

## Wyniki pięciu powtórzeń

Eksperyment przeprowadzono 3 czerwca 2026 roku.

| Powtórzenie | PR | Workflow run | Etap 5 status | FAIL-NEW | WARN-NEW | PASS | Czas trwania |
|-------------|----|--------------|---------------|----------|----------|------|--------------|
| 1 | #32 | #52 | ✓ success | 0 | 10 | 132 | 14 min 57 s |
| 2 | #33 | #54 | ✓ success | 0 | 10 | 132 | 14 min 45 s |
| 3 | #34 | #55 | ✓ success | 0 | 10 | 132 | 14 min 59 s |
| 4 | #35 | #56 | ✓ success | 0 | 10 | 132 | 15 min 17 s |
| 5 | #36 | #57 | ✓ success | 0 | 10 | 132 | 14 min 45 s |
| **Średnia** | — | — | **5/5** | **0,0** | **10,0** | **132** | **14 min 56 s** |

Bezprecedensowy **100% determinizm** — wszystkie pięć przebiegów zwróciło dokładnie tę samą liczbę alertów w każdej kategorii, co potwierdza, że ZAP w trybie pełnego skanowania aktywnego daje powtarzalne wyniki na stabilnej aplikacji testowej.

## Klasy alertów zarejestrowanych przez ZAP

W każdym z pięciu przebiegów ZAP raportował następujące alerty (najczęstsze, klasa `WARN-NEW`):

| Plugin ID | Nazwa alertu | Liczba instancji | Klasa OWASP |
|-----------|--------------|------------------|-------------|
| 40040 | CORS Misconfiguration | 94 | A05:2021 Security Misconfiguration |
| 10038 | Content Security Policy (CSP) Header Not Set | 11 | A05:2021 Security Misconfiguration |
| 10063 | Deprecated Feature Policy Header Set | 11 | A05:2021 Security Misconfiguration |
| 10098 | Cross-Domain Misconfiguration | 12 | A05:2021 Security Misconfiguration |
| 90004 | Cross-Origin-Embedder-Policy Header Missing or Invalid | 10 | A05:2021 Security Misconfiguration |
| 10017 | Cross-Domain JavaScript Source File Inclusion | 10 | A05:2021 Security Misconfiguration |
| 10095 | Backup File Disclosure | 31 | A01:2021 Broken Access Control |
| 40038 | Bypassing 403 | 5 | A01:2021 Broken Access Control |
| 10096 | Timestamp Disclosure - Unix | 1 | A02:2021 Cryptographic Failures |
| 10110 | Dangerous JS Functions | 2 | A03:2021 Injection (pomocniczy wskaźnik) |

Łącznie zarejestrowano **186 instancji alertów** w 10 klasach. W eksperymencie ZAP w trybie domyślnego pełnego skanu nie wykrył alertów klasy `FAIL-NEW`, co oznacza brak alertów o severity wystarczająco wysokim, by samodzielnie uzasadnić blokadę bramki w trybie standardowym. Wynika to z faktu, że klasyczny SQL Injection i XSS w Juice Shop wymagają autentykacji lub bardziej zaawansowanej eksploracji, do której skan bazowy nie dochodzi w przyjętym oknie czasowym.

## Interpretacja wyników w kontekście hipotez badawczych

Z perspektywy hipotezy szczegółowej **H1** (≥ 80% detekcji wprowadzonych podatności) — scenariusz D nie wprowadza nowych podatności, więc hipoteza ta nie ma bezpośredniego zastosowania. Mierzona jest pojemność narzędzia DAST w wykrywaniu podatności istniejących w deterministycznej aplikacji testowej. ZAP zarejestrował 10 klas alertów o łącznej liczbie 186 instancji w każdym z pięciu powtórzeń, co stanowi mocny dowód powtarzalności narzędzia.

Z perspektywy hipotezy szczegółowej **H3** (≤ 200% narzutu czasu względem baseline) — średni czas trwania workflow w scenariuszu D wynosi 896 s, czyli **103,8% czasu baseline** (T_baseline = 863 s). Różnica wynika z tego, że scenariusz D zawiera dokładnie ten sam workflow co baseline, jedynie z trywialną modyfikacją uruchamiającą przebieg. Tak małe odchylenie potwierdza, że T_baseline zostało zmierzone poprawnie i nie zawiera istotnych ukrytych czynników losowych.

## Zebrane artefakty dowodowe

- **20 zrzutów ekranu** (5 powtórzeń × 4 kategorie: strona PR, podsumowanie ZAP w logu workflow, lista alertów w logu, raport HTML otwarty lokalnie) w `docs/screenshots/scenario-d/run-1..5/`.
- **5 raportów ZAP** w trzech formatach (HTML, JSON, Markdown) w `data/raw/scenario-d/run-1..5/zap-baseline-report/` (lokalnie, poza repo).
- **5 zamkniętych pull requestów** w historii repozytorium (#32, #33, #34, #35, #36).
