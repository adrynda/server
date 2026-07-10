

```markdown
# 🤖 Lokalny Agent AI — Kompletna Instrukcja

## Spis treści

1. [Wymagania sprzętowe](#wymagania-sprzętowe)
2. [Przygotowanie środowiska](#przygotowanie-środowiska)
3. [Struktura projektu](#struktura-projektu)
4. [Konfiguracja](#konfiguracja)
5. [Uruchomienie](#uruchomienie)
6. [Jak używać](#jak-używać)
7. [Porównanie narzędzi (alternatywy)](#porównanie-narzędzi-alternatywy)
8. [Porównanie modeli AI](#porównanie-modeli-ai)
9. [Wskazówki i optymalizacja](#wskazówki-i-optymalizacja)
10. [Rozwiązywanie problemów](#rozwiązywanie-problemów)

---

## Wymagania sprzętowe

### Minimalne

| Komponent | Minimum | Rekomendowane |
|-----------|---------|---------------|
| CPU | 4 rdzenie | 8+ rdzeni |
| RAM | 8 GB | 16 GB+ |
| GPU VRAM | brak (CPU mode) | 6 GB+ (NVIDIA) |
| Dysk | 20 GB wolnego | 50 GB+ SSD |
| System | Windows 10/11 + WSL2 | Ubuntu 22.04+ |

### Testowany sprzęt (referencyjny)

- **CPU:** Intel i5-12500H (12 rdzeni)
- **RAM:** 16 GB DDR4
- **GPU:** NVIDIA RTX 3060 Mobile (6 GB VRAM)
- **Dysk:** 1 TB SSD
- **System:** Windows 11 + WSL2 (Ubuntu) + Docker

---

## Przygotowanie środowiska

### Krok 1: Sprawdź czy NVIDIA działa w WSL2

```bash
nvidia-smi
```

Powinieneś zobaczyć swoją kartę graficzną. Jeśli nie — zainstaluj
[NVIDIA Driver for WSL](https://developer.nvidia.com/cuda/wsl).

### Krok 2: Zainstaluj NVIDIA Container Toolkit

```bash
# Dodaj repozytorium NVIDIA
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Zainstaluj
sudo apt update
sudo apt install -y nvidia-container-toolkit

# Skonfiguruj Docker
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Krok 3: Zweryfikuj instalację

```bash
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi
```

Jeśli widzisz swoją kartę — środowisko jest gotowe.

---

## Struktura projektu

```
ai-agent/
├── compose.yaml                  # Główna konfiguracja Docker
├── searxng/
│   └── settings.yml              # Konfiguracja wyszukiwarki
├── aider_config/
│   └── .aider.conf.yml           # Konfiguracja agenta CLI
├── ollama_data/                  # Dane modeli AI (auto)
├── webui_data/                   # Dane interfejsu web (auto)
└── server/                       # TWÓJ PROJEKT (już istnieje)
    ├── compose.yaml
    ├── projects/
    │   ├── app1/
    │   │   ├── Dockerfile
    │   │   └── src/
    │   └── app2/
    │       ├── Dockerfile
    │       └── src/
    └── nginx/
        └── nginx.conf
```

---

## Konfiguracja

### Plik `compose.yaml`

```yaml
services:

  # ═══════════════════════════════════════
  # Silnik AI (Ollama)
  # ═══════════════════════════════════════
  ollama:
    image: ollama/ollama
    container_name: ollama
    ports:
      - "11434:11434"
    volumes:
      - ./ollama_data:/root/.ollama
    restart: unless-stopped
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    entrypoint: /bin/sh
    command: >
      -c "ollama serve &
      sleep 5 &&
      echo '=== Pobieranie modelu (tylko za pierwszym razem) ===' &&
      ollama pull qwen2.5-coder:7b &&
      echo '=== Model gotowy ===' &&
      wait"

  # ═══════════════════════════════════════
  # Wyszukiwarka internetowa (prywatna, lokalna)
  # ═══════════════════════════════════════
  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    ports:
      - "8888:8080"
    volumes:
      - ./searxng:/etc/searxng:rw
    restart: unless-stopped

  # ═══════════════════════════════════════
  # Web UI (czat w przeglądarce, jak ChatGPT)
  # ═══════════════════════════════════════
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    ports:
      - "3000:8080"
    volumes:
      - ./webui_data:/app/backend/data
      - ./server:/app/backend/data/docs/server:ro
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      # Web search
      - ENABLE_RAG_WEB_SEARCH=True
      - RAG_WEB_SEARCH_ENGINE=searxng
      - SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query>&format=json
    depends_on:
      - ollama
      - searxng
    restart: unless-stopped

  # ═══════════════════════════════════════
  # Agent CLI (jak Claude Code)
  # ═══════════════════════════════════════
  aider:
    image: paulgauthier/aider-full
    container_name: aider
    profiles:
      - cli
    volumes:
      - ./server:/workspace:rw
      - ./aider_config:/root/.aider:rw
    working_dir: /workspace
    environment:
      - OLLAMA_API_BASE=http://ollama:11434
    depends_on:
      - ollama
    stdin_open: true
    tty: true
    command: >
      --model ollama_chat/qwen2.5-coder:7b
      --no-auto-commits
      --no-git
      --map-tokens 2048
      --edit-format diff
```

### Plik `searxng/settings.yml`

```yaml
use_default_settings: true

general:
  instance_name: "AI Search"

search:
  safe_search: 0
  autocomplete: "duckduckgo"
  default_lang: "pl"
  formats:
    - html
    - json    # WAŻNE - Open WebUI wymaga formatu JSON

server:
  secret_key: "zmien-ten-klucz-na-losowy-ciag"
  bind_address: "0.0.0.0"
  port: 8080

engines:
  - name: duckduckgo
    engine: duckduckgo
    shortcut: ddg
    disabled: false

  - name: google
    engine: google
    shortcut: g
    disabled: false

  - name: github
    engine: github
    shortcut: gh
    disabled: false

  - name: stackoverflow
    engine: stackoverflow
    shortcut: so
    disabled: false

  - name: docker hub
    engine: docker_hub
    shortcut: dh
    disabled: false
```

### Plik `aider_config/.aider.conf.yml`

```yaml
# Wzorce plików do ignorowania (oszczędność tokenów)
ignore-patterns:
  - "node_modules"
  - ".git"
  - "venv"
  - "__pycache__"
  - "*.pyc"
  - "dist"
  - "build"
  - ".env"
  - "*.log"
  - "*.lock"
  - "*.sqlite"
  - "*.db"
  - "var/"
  - "vendor/"

# Optymalizacja dla 6 GB VRAM
map-tokens: 2048
edit-format: diff
```

### Plik `.aider.instructions.md` (w katalogu `server/`)

Przykład dla projektu PHP/Symfony:

```markdown
# Instrukcje projektu

## Stack technologiczny
- PHP 8.3
- Symfony 7.1
- Doctrine ORM 3.x
- Twig 3.x
- PHPUnit 11
- Docker + Docker Compose

## Zasady kodowania
- ZAWSZE używaj PHP 8 Attributes, NIGDY annotations
- Routing: #[Route], NIGDY @Route
- Doctrine: #[ORM\Column], NIGDY @ORM\Column
- Type hints na wszystkim (parametry, return types)
- Constructor promotion gdzie możliwe
- readonly properties gdzie możliwe
- Enum zamiast stałych tekstowych
- Odpowiadaj po polsku

## Struktura projektu
- src/Controller/ — kontrolery
- src/Entity/ — encje Doctrine
- src/Repository/ — repozytoria
- src/Service/ — logika biznesowa
- templates/ — szablony Twig
- config/ — konfiguracja YAML

## Komendy
- `php bin/console` — konsola Symfony
- `php bin/phpunit` — testy
- `composer install` — instalacja zależności
- `docker compose up -d` — uruchomienie kontenerów
```

---

## Uruchomienie

### Pierwsze uruchomienie (pobiera model ~4.5 GB)

```bash
# 1. Przejdź do katalogu projektu
cd ai-agent

# 2. Uruchom Ollama + WebUI + SearXNG
docker compose up -d

# 3. Śledź postęp pobierania modelu
docker compose logs -f ollama

# 4. Poczekaj na komunikat "Model gotowy"

# 5. Sprawdź czy GPU jest wykorzystywane
docker exec ollama nvidia-smi
```

### Kolejne uruchomienia (model już na dysku)

```bash
# Uruchom — model ładuje się w sekundach
docker compose up -d

# Uruchom agenta CLI
docker compose run --rm aider
```

### Dostępne adresy

| Usługa | Adres | Opis |
|--------|-------|------|
| Ollama API | http://localhost:11434 | API modelu AI |
| Open WebUI | http://localhost:3000 | Czat w przeglądarce |
| SearXNG | http://localhost:8888 | Wyszukiwarka |

### Pobieranie dodatkowych modeli

```bash
# Modele do kodu
docker exec ollama ollama pull qwen2.5-coder:7b
docker exec ollama ollama pull deepseek-coder-v2:lite
docker exec ollama ollama pull codellama:7b-instruct
docker exec ollama ollama pull starcoder2:7b

# Modele ogólne (do rozmów, analiz, dokumentacji)
docker exec ollama ollama pull llama3.1:8b
docker exec ollama ollama pull mistral:7b
docker exec ollama ollama pull gemma2:9b
docker exec ollama ollama pull phi3:medium

# Lista zainstalowanych modeli
docker exec ollama ollama list

# Usuwanie modelu
docker exec ollama ollama rm nazwa-modelu
```

---

## Jak używać

### Web UI (http://localhost:3000)

Przy pierwszym wejściu stwórz konto lokalne (dane nigdzie nie są wysyłane).

**Zwykły czat:**
```
Przeanalizuj strukturę mojego projektu i opisz architekturę
```

**Czat z wyszukiwaniem w internecie (kliknij ikonę 🌐):**
```
Wyszukaj dokumentację Symfony 7.1 Messenger
i pokaż jak skonfigurować async transport
```

**Czat z plikami (przeciągnij plik do okna czatu):**
```
Przeanalizuj ten plik i znajdź potencjalne problemy
```

**Funkcje Web UI:**
- Historia czatów (lista po lewej stronie)
- Wiele modeli do wyboru (przełączanie w górnym menu)
- Upload plików (PDF, TXT, DOCX, CSV, MD, kod źródłowy)
- Web search (ikona globusa)
- Eksport czatów

### CLI — Aider (terminal)

```bash
# Uruchom agenta
docker compose run --rm aider
```

**Podstawowe komendy Aidera:**

| Komenda | Opis |
|---------|------|
| `/add plik.php` | Dodaj plik do kontekstu AI |
| `/add .` | Dodaj cały katalog |
| `/drop plik.php` | Usuń plik z kontekstu |
| `/clear` | Wyczyść historię czatu (nowa sesja) |
| `/undo` | Cofnij ostatnią zmianę AI w plikach |
| `/diff` | Pokaż co AI zmieniło |
| `/web https://url` | Pobierz treść strony jako kontekst |
| `/help` | Lista wszystkich komend |
| `/exit` | Wyjdź |

**Przykładowe sesje pracy:**

```bash
# Analiza projektu
/add .
Opisz architekturę tego projektu i role poszczególnych serwisów

# Debugowanie
/add src/Controller/UserController.php
/add src/Service/UserService.php
Znajdź błędy w UserService — dostaję NullPointerException
w linii 45

# Tworzenie nowego kodu
Stwórz encję Product (name, price, description, createdAt),
repozytorium i kontroler REST z CRUD

# Dokumentacja z internetu
/web https://symfony.com/doc/current/messenger.html
Skonfiguruj Symfony Messenger w moim projekcie

# Refactoring
/add src/Service/OrderService.php
Ta klasa ma 500 linii. Rozbij ją na mniejsze serwisy
zgodnie z zasadą Single Responsibility
```

### API (curl / Postman / własna aplikacja)

```bash
# Proste zapytanie
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5-coder:7b",
  "prompt": "Napisz funkcję PHP sortującą tablicę",
  "stream": false
}'

# API kompatybilne z OpenAI (działa z bibliotekami OpenAI)
curl http://localhost:11434/v1/chat/completions -d '{
  "model": "qwen2.5-coder:7b",
  "messages": [
    {"role": "user", "content": "Napisz klasę UserRepository"}
  ]
}'
```

---

## Porównanie narzędzi (alternatywy)

### Silniki AI (zamienniki Ollama)

| Cecha | Ollama | LocalAI | vLLM | TGI (Hugging Face) |
|-------|--------|---------|------|---------------------|
| **Łatwość instalacji** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| **Wydajność** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Zarządzanie modelami** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| **API OpenAI-compatible** | ✅ | ✅ | ✅ | ✅ |
| **Obsługa CPU** | ✅ świetna | ✅ dobra | ❌ tylko GPU | ❌ tylko GPU |
| **Multi-model** | ✅ | ✅ | ❌ jeden model | ❌ jeden model |
| **RAM / VRAM** | niskie | średnie | wysokie | wysokie |
| **Dla kogo** | Każdy | Zaawansowani | Produkcja | Produkcja |

**Ollama** — najlepszy wybór dla lokalnego użytku. Prostota obsługi, niskie
wymagania, świetna integracja z narzędziami.

**LocalAI** — zamiennik, gdy potrzebujesz jednego API do tekstu, obrazów
(Stable Diffusion), audio (Whisper) i embeddings. Bardziej skomplikowany
w konfiguracji.

**vLLM** — silnik produkcyjny. Ekstremalnie szybki, ale wymaga mocnego GPU
(min. 24 GB VRAM) i obsługuje jeden model naraz. Nie dla laptopów.

**TGI** — silnik Hugging Face. Podobny do vLLM, używany w ich infrastrukturze
produkcyjnej. Stabilny, ale ciężki.

### Interfejsy Web (zamienniki Open WebUI)

| Cecha | Open WebUI | AnythingLLM | LibreChat | text-generation-webui |
|-------|------------|-------------|-----------|----------------------|
| **Wygląd** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **RAG (pliki)** | ✅ wbudowany | ✅ zaawansowany | ✅ | ❌ |
| **Web Search** | ✅ | ✅ | ✅ | ❌ |
| **Multi-model** | ✅ | ✅ | ✅ | ✅ |
| **Historia czatów** | ✅ | ✅ | ✅ | ✅ |
| **Multi-user** | ✅ | ✅ | ✅ | ❌ |
| **Łatwość instalacji** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Docker** | ✅ | ✅ | ✅ | ✅ |
| **Dla kogo** | Każdy | Bazy wiedzy | Multi-provider | Testowanie modeli |

**Open WebUI** — najlepszy ogólny interfejs. Wygląda jak ChatGPT, ma RAG,
web search, historię, multi-user. Idealne uzupełnienie Ollamy.

**AnythingLLM** — najlepszy do budowania "baz wiedzy" z dokumentów. Możesz
wskazać folder z plikami, a system automatycznie je zaindeksuje i pozwoli
zadawać pytania. Lepszy od Open WebUI gdy masz dużo dokumentów do analizy.

**LibreChat** — najlepszy gdy chcesz łączyć lokalne modele (Ollama) z
chmurowymi (OpenAI, Claude, Google). Jedno okno, wiele providerów.

**text-generation-webui (oobabooga)** — najlepszy do testowania i porównywania
modeli. Ma zaawansowane ustawienia generowania (temperature, top_p, penalties).
Mniej ładny, ale bardziej techniczny.

### Agenci CLI (zamienniki Aider)

| Cecha | Aider | Open Interpreter | SWE-agent | Continue (IDE) |
|-------|-------|------------------|-----------|----------------|
| **Edycja plików** | ✅ najlepsza | ✅ | ✅ | ✅ |
| **Pętla agentowa** | ✅ | ✅ zaawansowana | ✅ zaawansowana | ⚠️ podstawowa |
| **Repo Map** | ✅ unikalna | ❌ | ❌ | ⚠️ |
| **Git integracja** | ✅ najlepsza | ❌ | ✅ | ⚠️ |
| **Uruchamianie komend** | ⚠️ z flagą | ✅ natywnie | ✅ | ❌ |
| **Web scraping** | ✅ /web URL | ✅ samodzielnie | ❌ | ❌ |
| **Wsparcie Ollama** | ✅ | ✅ | ⚠️ | ✅ |
| **Oszczędność tokenów** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Łatwość użycia** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Dla kogo** | Programiści | Analitycy | Badacze | Użytkownicy IDE |

**Aider** — najlepszy agent do edycji kodu. Repo Map oszczędza tokeny
jak nic innego. Świetna integracja z git. Rekomendowany dla programistów.

**Open Interpreter** — najlepszy "ogólny agent". Może nie tylko edytować
pliki, ale też uruchamiać komendy, instalować paczki, tworzyć wykresy.
Bardziej ryzykowny (wykonuje kod na Twoim systemie), ale potężniejszy.

**SWE-agent** — agent od Princeton University zaprojektowany do
samodzielnego rozwiązywania issues na GitHubie. Bardzo zaawansowany,
ale trudny w konfiguracji i wymaga mocnego modelu.

**Continue** — rozszerzenie do VS Code / JetBrains. Nie jest CLI,
ale daje podobne możliwości bezpośrednio w edytorze. Idealne jeśli
wolisz pracować w IDE zamiast w terminalu.

### Wyszukiwarki (zamienniki SearXNG)

| Cecha | SearXNG | Tavily API | Serper API | DuckDuckGo API |
|-------|---------|------------|------------|----------------|
| **Koszt** | Darmowe | 1000/mies. free | 2500/mies. free | Darmowe |
| **Prywatność** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Jakość wyników** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Self-hosted** | ✅ | ❌ | ❌ | ❌ |
| **Format dla AI** | JSON/HTML | Czysty tekst | JSON | JSON |
| **Dla kogo** | Prywatność | Najlepsza jakość | Programiści | Prostota |

**SearXNG** — jedyna w pełni prywatna opcja. Działa lokalnie w Dockerze,
agreguje wyniki z wielu wyszukiwarek (Google, DuckDuckGo, Bing).
Nie wymaga żadnych kluczy API.

**Tavily** — stworzone specjalnie dla agentów AI. Zamiast surowego HTML
zwraca czysty, przetworzony tekst. Najlepsza jakość wyników, ale wymaga
rejestracji i klucza API (1000 zapytań/miesiąc za darmo).

---

## Porównanie modeli AI

### Modele do kodu (główne zastosowanie)

| Model | Rozmiar | VRAM | RAM (CPU) | Szybkość* | PHP/Symfony | Docker/DevOps | Ogólny kod | Polski |
|-------|---------|------|-----------|-----------|-------------|---------------|------------|--------|
| **Qwen2.5-Coder 7B** | ~4.5 GB | 5 GB | 8 GB | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Qwen2.5-Coder 14B** | ~9 GB | 10 GB | 16 GB | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Qwen2.5-Coder 32B** | ~20 GB | 24 GB | 32 GB | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **DeepSeek-Coder-V2 Lite** | ~9 GB | 10 GB | 16 GB | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **CodeLlama 7B** | ~4 GB | 5 GB | 8 GB | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **CodeLlama 13B** | ~8 GB | 10 GB | 16 GB | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **StarCoder2 7B** | ~4.5 GB | 5 GB | 8 GB | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |

*\*Szybkość na RTX 3060 6GB VRAM*

### Modele ogólne (dokumentacja, analiza, rozmowy)

| Model | Rozmiar | VRAM | RAM (CPU) | Szybkość* | Analiza tekstu | Reasoning | Polski | Kod |
|-------|---------|------|-----------|-----------|----------------|-----------|--------|-----|
| **Llama 3.1 8B** | ~4.5 GB | 5 GB | 8 GB | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Mistral 7B** | ~4 GB | 5 GB | 8 GB | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Mistral Small 22B** | ~14 GB | 16 GB | 24 GB | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Gemma 2 9B** | ~5.5 GB | 7 GB | 12 GB | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Phi-3 Medium 14B** | ~8 GB | 10 GB | 16 GB | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **LLaVA 7B** | ~4.5 GB | 5 GB | 8 GB | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |

*\*Szybkość na RTX 3060 6GB VRAM*

### Opisy modeli — kiedy którego używać

#### Qwen2.5-Coder 7B ⭐ REKOMENDOWANY
**Producent:** Alibaba (Qwen Team)
**Komenda:** `ollama pull qwen2.5-coder:7b`
**Najlepszy do:** Codziennej pracy z kodem — edycja, debugowanie, refactoring.
**Dlaczego:** Najlepszy stosunek jakości do szybkości na 6 GB VRAM.
Mieści się w całości na GPU, więc odpowiedzi są błyskawiczne (2-5 sekund).
Bardzo dobrze rozumie PHP, Python, JavaScript, Docker, YAML.
**Ograniczenia:** Może mieszać stare i nowe wersje frameworków (np. Symfony
annotations vs attributes). Rozwiązanie: plik `.aider.instructions.md`
z zasadami kodowania.

#### Qwen2.5-Coder 14B
**Producent:** Alibaba (Qwen Team)
**Komenda:** `ollama pull qwen2.5-coder:14b`
**Najlepszy do:** Trudnych refactoringów, analizy złożonej architektury.
**Dlaczego:** Znacznie "mądrzejszy" od wersji 7B. Lepiej rozumie
kontekst biznesowy kodu, lepiej radzi sobie z długimi plikami.
**Na Twoim sprzęcie:** ~6 GB na GPU + ~4 GB na RAM (CPU offload).
Wolniejszy (5-15 sekund na odpowiedź), ale warto przełączyć się
na niego przy złożonych zadaniach.

#### DeepSeek-Coder-V2 Lite (16B)
**Producent:** DeepSeek (Chiny)
**Komenda:** `ollama pull deepseek-coder-v2:lite`
**Najlepszy do:** Debugowania skomplikowanych błędów, rozumienia złożonej
logiki programistycznej.
**Dlaczego:** Architektura Mixture of Experts (MoE) — mimo 16B parametrów,
aktywuje tylko część z nich przy każdym tokenie, co czyni go
zaskakująco szybkim. Genialny w znajdowaniu bugów.
**Na Twoim sprzęcie:** Podobnie jak Qwen 14B — częściowo na GPU,
częściowo na RAM. Odpowiedzi w 5-10 sekund.

#### CodeLlama 7B
**Producent:** Meta (Facebook)
**Komenda:** `ollama pull codellama:7b-instruct`
**Najlepszy do:** Prostych zadań kodowych, gdy potrzebujesz stabilności.
**Dlaczego:** Klasyk. Bardzo przewidywalny, rzadko "halucynuje".
Dobry na szybkie generowanie boilerplate'u.
**Ograniczenia:** Starsze dane treningowe. Może nie znać najnowszych
wersji frameworków. Słabszy w PHP niż Qwen/DeepSeek.

#### StarCoder2 7B
**Producent:** Hugging Face + ServiceNow
**Komenda:** `ollama pull starcoder2:7b`
**Najlepszy do:** Generowania czystego kodu bez zbędnych komentarzy.
**Dlaczego:** Trenowany na kodzie z licencjami permissive (Apache, MIT).
Generuje bardzo "czysty", idiomatyczny kod.
**Ograniczenia:** Mniej "rozmowny" — wymaga precyzyjnych promptów.
Gorzej radzi sobie z wyjaśnianiem kodu.

#### Llama 3.1 8B
**Producent:** Meta (Facebook)
**Komenda:** `ollama pull llama3.1:8b`
**Najlepszy do:** Analizy architektury, pisania dokumentacji, opisywania
projektów.
**Dlaczego:** Najlepszy model ogólny w kategorii 8B. Świetnie pisze
po polsku, dobrze rozumie kontekst biznesowy. Używaj go gdy pytasz
"dlaczego tak, a nie inaczej" zamiast "napisz kod".

#### Mistral Small 22B
**Producent:** Mistral AI (Francja)
**Komenda:** `ollama pull mistral-small`
**Najlepszy do:** Zaawansowanej analizy i reasoning'u w języku polskim.
**Dlaczego:** Europejski model, świetnie rozumie polskie nazwy zmiennych
i kontekst. Bardzo logiczny — potrafi prowadzić złożone rozumowanie.
**Na Twoim sprzęcie:** Będzie WOLNY (1-2 słowa/sekundę). Większość
obliczeń na CPU. Używaj tylko do szczególnie trudnych problemów.

#### LLaVA 7B (model wizualny)
**Producent:** Microsoft Research
**Komenda:** `ollama pull llava`
**Najlepszy do:** Analizy obrazów, screenshotów, diagramów.
**Dlaczego:** Jedyny model na tej liście, który "widzi" obrazki.
Możesz mu wysłać screenshot błędu, diagram architektury,
wireframe UI — i on go opisze/przeanalizuje.

### Rekomendowane zestawy modeli

#### Zestaw "Lekki" (8 GB RAM, 4-6 GB VRAM)
```bash
ollama pull qwen2.5-coder:7b    # Do kodu
ollama pull llama3.1:8b          # Do rozmów i dokumentacji
# Razem: ~9 GB na dysku
```

#### Zestaw "Optymalny" (16 GB RAM, 6 GB VRAM) ⭐ REKOMENDOWANY
```bash
ollama pull qwen2.5-coder:7b       # Daily driver — szybki
ollama pull deepseek-coder-v2:lite  # Trudne bugi — mądrzejszy
ollama pull llama3.1:8b             # Dokumentacja i analiza
# Razem: ~18 GB na dysku
```

#### Zestaw "Maksymalny" (32 GB RAM, 8+ GB VRAM)
```bash
ollama pull qwen2.5-coder:14b      # Główny model do kodu
ollama pull deepseek-coder-v2:lite  # Alternatywa
ollama pull mistral-small           # Reasoning i polski
ollama pull llava                   # Analiza obrazów
# Razem: ~35 GB na dysku
```

---

## Wskazówki i optymalizacja

### Oszczędzanie tokenów (VRAM)

1. **Używaj `/add` selektywnie w Aiderze.**
   Zamiast `/add .` dodawaj tylko pliki nad którymi pracujesz.
   Resztę Aider "widzi" przez Repo Map (sygnatura klas/funkcji).

2. **Korzystaj z `.aiderignore`.**
   Wyklucz `vendor/`, `node_modules/`, `var/`, `.git/`, logi, bazy danych.

3. **Używaj `/clear` gdy sesja się wydłuża.**
   Czyści historię czatu, ale zostawia dodane pliki.

4. **Krótkie, precyzyjne polecenia.**
   Zamiast: "Zrób mi cały CRUD" → "Stwórz Entity Product z polami: name
   (string), price (float), createdAt (datetime)"

### Praca z logami i plikami ignorowanymi

Pliki w `.aiderignore` (np. `*.log`) nie są automatycznie czytane
przez Aidera. Aby użyć ich do debugowania:

```bash
# Opcja 1: Wymuś dodanie pliku
/add error.log

# Opcja 2: Skopiuj fragment (bezpieczniejsze dla tokenów)
tail -n 50 var/log/dev.log > debug_context.txt
/add debug_context.txt

# Opcja 3: Wklej stack trace bezpośrednio do czatu
# (po prostu wklej treść błędu jako wiadomość)

# Po zakończeniu debugowania:
/drop error.log
/drop debug_context.txt
```

### Plik instrukcji (odpowiednik CLAUDE.md)

Aider automatycznie czyta plik `.aider.instructions.md` z katalogu
projektu. Umieść tam:
- Wersje frameworków i bibliotek
- Zasady kodowania (np. "używaj atrybutów PHP 8, nie annotations")
- Wzorce kodu (przykłady Entity, Controller, Service)
- Komendy budowania i testowania
- Strukturę katalogów

Model będzie się do tych zasad stosował w każdej sesji.

### Przełączanie modeli w trakcie pracy

```bash
# W Aiderze — zmień model bez wychodzenia
/model ollama_chat/deepseek-coder-v2:lite

# Lub uruchom Aidera z innym modelem
docker compose run --rm aider \
  --model ollama_chat/deepseek-coder-v2:lite

# W Open WebUI — wybierz model z dropdown'a w górnym menu
```

---

## Rozwiązywanie problemów

### GPU nie jest wykrywane

```bash
# Sprawdź czy NVIDIA Container Toolkit jest zainstalowany
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi

# Jeśli błąd — przeinstaluj toolkit
sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Model odpowiada wolno

```bash
# Sprawdź czy model używa GPU
docker exec ollama ollama ps

# Jeśli w kolumnie "processor" jest "cpu" zamiast "gpu":
# 1. Sprawdź czy deploy.resources jest w compose.yaml
# 2. Restart: docker compose down && docker compose up -d
```

### Brak pamięci (OOM)

```bash
# Zmniejsz rozmiar kontekstu w Aiderze
# W compose.yaml zmień:
--map-tokens 1024   # zamiast 2048

# Lub użyj mniejszego modelu
ollama pull qwen2.5-coder:3b   # Najmniejszy, ale najszybszy
```

### SearXNG nie zwraca wyników

```bash
# Sprawdź czy settings.yml ma format JSON
# W searxng/settings.yml upewnij się że jest:
formats:
  - html
  - json

# Restart SearXNG
docker compose restart searxng
```

### Aider nie widzi plików

```bash
# Sprawdź czy wolumen jest poprawnie zamontowany
docker compose run --rm aider ls -la /workspace

# Upewnij się że ścieżka w compose.yaml jest poprawna:
# volumes:
#   - ./server:/workspace:rw
```

### Przydatne komendy diagnostyczne

```bash
# Status wszystkich kontenerów
docker compose ps

# Logi konkretnego kontenera
docker compose logs -f ollama
docker compose logs -f open-webui
docker compose logs -f searxng

# Zużycie zasobów
docker stats

# Ile miejsca zajmują modele
du -sh ./ollama_data

# Lista modeli
docker exec ollama ollama list

# Zatrzymanie bez usuwania danych
docker compose down

# Pełny reset (UWAGA: usuwa dane WebUI, NIE modele jeśli są w ./ollama_data)
docker compose down -v
```

---

## Licencje

| Komponent | Licencja |
|-----------|----------|
| Ollama | MIT |
| Open WebUI | MIT |
| SearXNG | AGPL-3.0 |
| Aider | Apache 2.0 |
| Qwen2.5-Coder | Apache 2.0 (komercyjne użycie OK) |
| Llama 3.1 | Meta Llama License (komercyjne użycie OK) |
| DeepSeek-Coder-V2 | DeepSeek License (komercyjne użycie OK) |
| Mistral | Apache 2.0 |
| CodeLlama | Meta Llama License |
| StarCoder2 | BigCode Open RAIL-M |

Wszystkie wymienione narzędzia i modele są **darmowe do użytku
osobistego i komercyjnego**.
```

Gotowe. Cały plik `.md` zawiera:

1. **Instrukcję krok po kroku** — od instalacji NVIDIA Toolkit po uruchomienie
2. **Kompletny `compose.yaml`** — Ollama + Open WebUI + SearXNG + Aider
3. **Porównanie alternatyw** — silniki AI, interfejsy web, agenci CLI, wyszukiwarki
4. **Porównanie modeli** — z wymaganiami sprzętowymi, oceną dla PHP/Symfony i opisami kiedy którego używać
5. **Rekomendowane zestawy modeli** — dla różnych konfiguracji sprzętowych
6. **Wskazówki** — oszczędzanie tokenów, praca z logami, przełączanie modeli
7. **Troubleshooting** — rozwiązania najczęstszych problemów