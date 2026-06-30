# Podsumowanie całego stosu

## Narzędzia

### Etap 1 - Lokalnie (dev)

| Narzędzie | Opis |
|-----------|------|
| **Traefik** | Reverse proxy, routing domen, SSL |
| **Portainer** | GUI zarządzanie kontenerami Docker |
| **Adminer** | GUI zarządzanie bazami danych |
| **Mailpit** | Łapanie i podgląd maili lokalnie |
| **Dozzle** | Podgląd logów wszystkich kontenerów |
| **Netdata** | Monitoring zasobów (CPU, RAM, dysk) |
| **Restic** | Klient backupów CLI |
| **MinIO** | Lokalny S3 - miejsce docelowe dla Restic |

### Etap 2 - VPS / Sandbox

| Narzędzie | Opis |
|-----------|------|
| **Tailscale** | VPN - bezpieczny dostęp do narzędzi admin |
| **Authelia** | SSO + 2FA - jeden login dla wszystkich subdomen |
| **Watchtower** | Automatyczna aktualizacja kontenerów (CI/CD) |
| **GitHub/GitLab CI** | Pipeline budowania i deploymentu |

### Etap 3 - Produkcja

| Narzędzie | Opis |
|-----------|------|
| **CrowdSec** | Ochrona przed atakami, blacklisty |
| **Restic** | Ten sam co lokalnie → AWS S3 / Backblaze B2 |
| **Stalwart** | Własny serwer pocztowy |

### Nigdy / Zastąpione

| Narzędzie | Zastępuje |
|-----------|-----------|
| ~~Mailhog~~ | Mailpit |
| ~~Maildev~~ | Mailpit |
| ~~Duplicati~~ | Restic |
| ~~Prometheus+Grafana~~ | Netdata (chyba że duża infrastruktura) |
| ~~Vaultwarden~~ | KeePassXC + wtyczka do przeglądarki |

---

## Architektura sieci

```
Internet
└── Traefik (public)
    ├── stronaA.pl          → app (public + internal)
    ├── stronaB.pl          → app (public + internal)
    ├── sandbox.stronaA.pl  → app sandbox (public + internal)
    ├── adminer.pl          → Adminer (za Authelia)
    ├── portainer.pl        → Portainer (za Tailscale)
    └── netdata.pl          → Netdata (za Tailscale)

Sieć internal (nigdy publiczna)
└── PostgreSQL / MySQL
    └── dostęp tylko dla app i Adminer

DBeaver
└── SSH Tunnel → VPS → baza internal
```

---

## Struktura domen

```
twojadomena.pl (techniczna - Twoja)
├── portainer.twojadomena.pl     → Tailscale only
├── adminer.twojadomena.pl       → Tailscale / Authelia
├── netdata.twojadomena.pl       → Tailscale only
├── dozzle.twojadomena.pl        → Tailscale only
├── sandbox.stronaA.twojadomena.pl → Authelia (klient może zobaczyć)
└── sandbox.stronaB.twojadomena.pl → Authelia

stronaA.pl (klienta)             → publiczna
stronaB.pl (klienta)             → publiczna
```

---

## Dostęp i bezpieczeństwo

```
Ty (developer)
├── Narzędzia admin  → Tailscale VPN
├── Baza danych      → DBeaver przez SSH Tunnel
└── Sandbox          → Tailscale / Authelia

Klient
└── Sandbox podgląd  → Authelia (login jednorazowy)

Świat
├── Strony produkcyjne → publiczne przez Traefik
└── Wszystko inne      → zablokowane ✅
```

---

## Backup

```
Lokalnie:
└── Restic → MinIO (lokalny S3)

Produkcja:
└── Restic → Backblaze B2 / AWS S3

Zmiana tylko endpoint URL - komendy identyczne ✅
```

---

## Email

```
Lokalnie:
└── Mailpit (łapie wszystkie maile, GUI podgląd)
    .env: MAILER_DSN=smtp://localhost:1025

Produkcja:
└── Stalwart (własny serwer)
    lub Mailgun / Sendgrid (zewnętrzny SMTP)
```

---

## CI/CD

```
Push kodu → GitHub/GitLab
         → Actions/CI buduje obraz Docker
         → Push do Registry
         → Watchtower wykrywa nowy obraz
         → Automatyczny deploy na sandbox ✅
```

---

## Hosting

```
Hetzner VPS (rekomendacja)
├── CX22: 4GB RAM / 2vCPU / 40GB → ~5€/mc
└── Wystarczy na start

Alternatywy PL (drożej, wsparcie PL):
├── home.pl
└── kylos.pl
```