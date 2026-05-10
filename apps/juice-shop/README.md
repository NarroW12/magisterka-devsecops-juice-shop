# OWASP Juice Shop — uruchomienie

Konfiguracja `docker-compose.yml` w tym katalogu uruchamia oficjalny obraz `bkimminich/juice-shop` w wersji `v17.2.0`. W eksperymencie Juice Shop pełni rolę aplikacji testowej dla scenariusza D (DAST z OWASP ZAP).

## Lokalne uruchomienie

```bash
cd apps/juice-shop
docker compose up -d
```

Aplikacja jest dostępna pod adresem `http://localhost:3000`. Aby zatrzymać:

```bash
docker compose down
```

## Powiązanie z eksperymentem

Pełen kod źródłowy OWASP Juice Shop **NIE jest** częścią tego repozytorium. Jeśli potrzebujesz wglądu w źródła (np. do weryfikacji konkretnej podatności), referencyjny klon znajduje się poza repozytorium w katalogu `seminarium_magisterka/_reference_juice_shop_source/`.
