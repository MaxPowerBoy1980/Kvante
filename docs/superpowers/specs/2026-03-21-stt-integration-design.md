# STT Integration Design — Whisper + AI Action Matching

**Dato:** 2026-03-21
**Status:** Godkendt

## Mål

Tilføj et `/stt` endpoint til Kvante-backenden der konverterer dansk tale til tekst via Whisper, og matcher transskriptionen mod tilgængelige `structured_prompts` via den eksisterende AI-klient. Eleven kan tale i stedet for at trykke på knapper.

## Beslutninger

| Beslutning | Valg | Begrundelse |
|---|---|---|
| Scope | Kun STT (tale → tekst), ikke TTS | TTS (Plapre) designes separat |
| Hvad eleven siger | Knap-matching, ikke fritekst | Kardinalreglen: forhindrer at eleven beder om svaret. Matcher "strukturerede prompts"-princippet |
| Matching-strategi | AI-baseret (Gemini/Claude) | Robust mod variationer i hvordan børn formulerer sig. Minimalt token-forbrug |
| Endpoint-design | Alt-i-én: lyd ind → action ud | Én roundtrip fra iPad, al logik backend-side |
| Lydformat | AAC/M4A | iOS's native format, Whisper understøtter det direkte |
| Max optagelse | 5 sekunder | Nok til korte kommandoer, holder latency lav |
| Arkitektur | Singleton, eager loading i lifespan | Forudsigelig latency fra første request. Ingen load ved disabled |
| Default | Deaktiveret (`STT_ENABLED=false`) | Kan aktiveres når latency er valideret |

## Config

Tilføjelser til `Settings` i `config.py`:

```python
stt_enabled: bool = False          # Deaktiveret som default
stt_model: str = "tiny"            # Whisper model: tiny, base, small
stt_max_duration: int = 5          # Max optagelseslængde i sekunder
stt_language: str = "da"           # Fastlåst til dansk
```

Env vars: `KVANTE_STT_ENABLED`, `KVANTE_STT_MODEL`, `KVANTE_STT_MAX_DURATION`, `KVANTE_STT_LANGUAGE`.

## STT Service

Ny fil: `backend/app/services/stt_service.py`

### Klasse: `STTService`

```
STTService
├── __init__(model_name: str)     # Loader faster-whisper model
├── transcribe(audio_bytes) → str  # Whisper transskription
└── match_action(transcription, available_actions, ai_client) → MatchResult
```

### `transcribe(audio_bytes: bytes) → str`

1. Skriv AAC bytes til tempfil (faster-whisper kræver filsti)
2. Kør Whisper med `language="da"`
3. Log latency
4. Returner transskriberet tekst

### `match_action(transcription, available_actions, ai_client) → MatchResult`

1. Modtag transskription + liste af `StructuredPrompt` (id + label)
2. Send til eksisterende AI-klient med prompt: "Eleven sagde: '{tekst}'. Hvilken af disse handlinger mente de? Returner JSON med action id og confidence."
3. Returner `MatchResult`

### Response-model

```python
class MatchResult(BaseModel):
    transcription: str           # Hvad Whisper hørte
    matched_action: str | None   # Action id, eller None hvis ingen match
    confidence: float            # AI'ens confidence (0-1)
```

Hvis confidence er under `settings.confidence_threshold` (0.6, allerede defineret i eksisterende config — genbruges, ikke ny setting), sættes `matched_action = None`.

## Router

Ny fil: `backend/app/routers/stt.py`

### `POST /stt`

**Request**: Multipart form data:
- `audio`: UploadFile (AAC/M4A)
- `submission_id`: string — ID på den aktive submission (bruges til at slå sprog og kontekst op)

**Response (200)** — match fundet:
```json
{
    "transcription": "forklar det på en anden måde",
    "matched_action": "explain_different",
    "confidence": 0.85
}
```

**Response (200)** — ingen match:
```json
{
    "transcription": "øhm jeg ved ikke",
    "matched_action": null,
    "confidence": 0.3
}
```

**Response (503)** — disabled:
```json
{
    "error": "STT disabled",
    "fallback": true
}
```

**Headers**: `X-STT-Latency-Ms` med samlet tid (Whisper + AI-matching).

**Validering**: Max ~500 KB filstørrelse (5 sek AAC). Returnerer 400 hvis overskredet.

### Tilgængelige actions

Routeren henter action-labels fra `STRUCTURED_PROMPTS` i `feedback_generator.py` (filtreret på sprog via submission → session → `detected_language`). AI-matchingen matcher kun mod actions der er i `VALID_ACTIONS` sættet i `feedback.py` (`explain_different`, `another_example`, `show_first_step`, `what_did_well`, `try_again`, `explain_task`). `next_assignment` er en navigationshandling og medtages **ikke** i matchingen — den håndteres kun via knapper i iOS.

Flowet efter match: iOS modtager `matched_action` → kalder `POST /feedback/{submission_id}/followup` med den action. STT-endpointet udfører ikke selve followup'en.

## Startup (lifespan)

I `main.py` `lifespan()`, efter database-initialisering:

```python
stt_service = None
if settings.stt_enabled:
    from app.services.stt_service import STTService
    stt_service = STTService(model_name=settings.stt_model)
    logger.info("STT loaded: model=%s, language=%s", settings.stt_model, settings.stt_language)

app.state.stt_service = stt_service
```

Routeren henter servicen via `request.app.state.stt_service`. Registreres i `main.py`:
```python
app.include_router(stt.router)
```

## Fejlhåndtering

| Scenario | Respons | Effekt |
|---|---|---|
| STT disabled | 503: `{"error": "STT disabled", "fallback": true}` | iOS falder tilbage til knapper |
| Whisper fejler | 503: `{"error": "Transcription failed", "fallback": true}` | iOS falder tilbage til knapper |
| AI-matching fejler | 200: returnerer transskription med `matched_action: null` | iOS viser transskription + knapper |

Princip: STT-fejl må **aldrig** crashe serveren eller blokere knapbaseret interaktion.

## Dependencies

Tilføj til `requirements.txt`:
```
faster-whisper==1.1.0
```

`faster-whisper` bruger CTranslate2 — optimeret til CPU-inferens. Downloader Whisper-modeller automatisk ved første brug og cacher dem lokalt.

## Test med curl

```bash
# Disabled (default)
curl -X POST http://localhost:8000/stt \
  -F "audio=@test.m4a" \
  -F "submission_id=some-id"
# → 503: {"error": "STT disabled", "fallback": true}

# Enabled (KVANTE_STT_ENABLED=true)
curl -X POST http://localhost:8000/stt \
  -F "audio=@test.m4a" \
  -F "submission_id=some-submission-id" \
  -v  # -v for at se X-STT-Latency-Ms header
```
