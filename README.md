# docker-server

Lokalny poligon: Traefik + obrazy per projekt (Docker + WSL2).

## Struktura

```
_infrastructure/
├── docker-compose.yml      # ROOT — definiuje sieć 'web' + include wszystkich narzędzi
├── traefik/
│   ├── Dockerfile
│   └── docker-compose.yml
└── db/
    ├── Dockerfile
    └── docker-compose.yml  # baza + Adminer

projects/
└── projekt-testowy/
    ├── Dockerfile
    ├── docker-compose.yml  # podłącza się do sieci 'web' jako external
    └── src/
```

## Sieć

Sieć `web` jest definiowana **raz**, w `_infrastructure/docker-compose.yml`.
Wszystkie projekty referencują ją jako `external: true` — same jej nie tworzą,
tylko się do niej podłączają.

## Użycie — infrastruktura (serwer)

```bash
cd _infrastructure
docker compose build      # budowanie obrazów Traefika, DB itd.
docker compose up -d      # start wszystkiego: sieć + Traefik + DB + Adminer
docker compose down       # stop
```

Dashboard Traefika: http://localhost:8080
Adminer: http://adminer.localhost

## Użycie — projekt

```bash
cd projects/projekt-testowy
docker compose build
docker compose up -d
```

Projekt dostępny pod: http://projekt-testowy.localhost

**Ważne:** infrastruktura musi być wystartowana wcześniej (sieć `web` musi
istnieć), zanim odpalisz projekt.

## Dodawanie nowego narzędzia do infrastruktury

1. Nowy katalog w `_infrastructure/nazwa-narzedzia/` z `Dockerfile` + `docker-compose.yml`
2. Dodaj wpis w `include:` w `_infrastructure/docker-compose.yml`
3. `docker compose up -d` w `_infrastructure/`

## Dodawanie nowego projektu

1. Nowy katalog w `projects/nazwa-projektu/` z `Dockerfile` + `docker-compose.yml`
   (skopiuj wzorzec z `projects/projekt-testowy/`)
2. `docker compose build && docker compose up -d` w tym katalogu

Żadne istniejące pliki infrastruktury nie wymagają edycji przy dodaniu projektu.
