# Kvante

Kvante er en paper-first AI matematikhjælper til folkeskoleelever (9-13 år). Eleven arbejder med blyant og papir — iPad'en er kun kamera og feedback-skærm.

## Kardinalregel

**Kvante må ALDRIG afsløre svaret på den faktiske opgave.** Kun vise gennemregnede eksempler med andre tal.

## Arkitektur

```
┌─────────────────┐         ┌──────────────────┐
│  iOS App (iPad)  │◄──────►│  Backend (Mac Mini)│
│  SwiftUI         │ Bonjour │  FastAPI + Python  │
│  VisionKit       │  LAN    │  SQLite            │
└─────────────────┘         └────────┬───────────┘
                                     │
                                     ▼
                              ┌──────────────┐
                              │  AI Provider  │
                              │  Gemini/Claude│
                              └──────────────┘
```

### Backend (Mac Mini: 192.168.1.60)
- **Framework**: FastAPI + uvicorn, port 8000
- **Database**: SQLite via SQLAlchemy ORM
- **AI**: Gemini (default, gratis tier) eller Claude — factory pattern i `services/ai_client.py`
- **Discovery**: Bonjour `_kvante._tcp` via AsyncZeroconf
- **Logs**: `~/Library/Logs/Kvante/kvante.log` (RotatingFileHandler)
- **Kode**: `backend/`

### iOS App
- **Framework**: SwiftUI, deployment target iOS 26.2
- **Scanner**: VisionKit document scanner
- **Netværk**: NWBrowser for Bonjour discovery → URLSession til API
- **Kode**: `ios/Kvante/`

## API Endpoints

| Endpoint | Beskrivelse |
|----------|-------------|
| `GET /health` | Health check (Bonjour verifikation) |
| `POST /pages/scan` | Upload foto af tekstbogside → parser opgaver |
| `POST /sessions/{id}/assignments/{id}/example` | Generer gennemregnet eksempel |
| `POST /submissions/` | Upload foto af elevens håndskrevne arbejde |
| `POST /feedback/` | Generer feedback på elevens metode |
| `POST /feedback/{id}/followup` | Håndter strukturerede opfølgningsspørgsmål |

## Filstruktur

```
backend/
├── app/
│   ├── routers/        # health, pages, assignments, submissions, feedback
│   ├── services/       # ai_client, image_preprocessor, page_parser, etc.
│   ├── models/         # db.py (SQLAlchemy), schemas.py (Pydantic)
│   ├── prompts/        # System prompts som .txt filer
│   ├── main.py         # FastAPI app + Bonjour registrering
│   └── config.py       # Settings via environment
├── com.kvante.backend.plist  # launchd daemon config
└── requirements.txt

ios/Kvante/
├── Kvante.xcodeproj/
└── Kvante/
    ├── Models/         # APIResponses, Assignment, Session, etc.
    ├── Services/       # APIClient, ServerDiscovery
    ├── Views/          # HomeView, WorkingView, FeedbackView, etc.
    ├── ContentView.swift
    └── KvanteApp.swift

docs/superpowers/       # Originale specs og planer
```

## Netværk

- Mac Mini: `192.168.1.60` (ethernet) / `192.168.1.88` (sekundær)
- Bonjour service: `_kvante._tcp` port 8000
- Begge maskiner har Tailscale — mDNS kræver at Zeroconf bindes til LAN-IP, ikke alle interfaces

## AI Provider

Konfigureres via environment:
- `KVANTE_AI_PROVIDER=gemini` (default) eller `claude`
- `KVANTE_GOOGLE_API_KEY` for Gemini
- `KVANTE_ANTHROPIC_API_KEY` for Claude
- Factory: `get_ai_client()` i `services/ai_client.py`

## Kerneprincipper

1. **Paper-first**: Eleven skriver med blyant på papir, aldrig på skærm
2. **Aldrig giv svaret**: Kun eksempler med andre tal
3. **Metode over svar**: Feedback fokuserer på fremgangsmåde
4. **Strukturerede prompts**: Eleven vælger knapper, skriver ikke
5. **Transparens**: System prompts gemt som læsbare .txt filer
6. **Privatliv**: Alt på lokalt netværk, ingen cloud-lagring af fotos
