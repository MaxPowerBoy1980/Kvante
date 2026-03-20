# Multi-Provider AI Client

**Date:** 2026-03-20
**Status:** Approved
**Goal:** Replace the Claude-only `ClaudeClient` with a provider-agnostic interface. Add Google Gemini as a provider. Select via config.

## Problem

The backend hardcodes `ClaudeClient` for all AI calls. The user's Anthropic API account has no credits. Google Gemini offers a free tier (15 RPM) with strong vision and structured output — sufficient for demo/testing.

## Design

### Abstract Interface

A base class `AIClient` with two methods:

- `send_text(system_prompt: str, user_message: str) -> str`
- `send_vision(system_prompt: str, image_bytes: bytes, user_message: str, media_type: str) -> str`

### Implementations

- `ClaudeAIClient` — existing logic from `claude_client.py`, renamed
- `GeminiAIClient` — new, using `google-genai` SDK

### Factory

`get_ai_client() -> AIClient` reads `settings.ai_provider` and returns the correct implementation.

### Config Changes

New fields in `Settings`:

| Field | Env var | Default | Notes |
|-------|---------|---------|-------|
| `ai_provider` | `KVANTE_AI_PROVIDER` | `"gemini"` | `"gemini"` or `"claude"` |
| `google_api_key` | `KVANTE_GOOGLE_API_KEY` | `""` | Required when provider is gemini |
| `gemini_model` | `KVANTE_GEMINI_MODEL` | `"gemini-2.5-flash"` | Free tier model |

`anthropic_api_key` becomes optional (default `""`) so the app can start without it when using Gemini.

### Service Changes

All four services change one line each:

```python
# Before
from app.services.claude_client import ClaudeClient
self.claude = ClaudeClient()

# After
from app.services.ai_client import get_ai_client
self.client = get_ai_client()
```

Method calls remain identical — `send_text()` and `send_vision()` signatures are the same.

### Gemini Vision API

The `google-genai` SDK accepts images as `Part.from_bytes(data=image_bytes, mime_type=media_type)`. System instructions are passed via the `config` parameter.

### Files Changed

| File | Change |
|------|--------|
| `services/ai_client.py` | New — abstract base, both implementations, factory |
| `services/claude_client.py` | Deleted (moved into ai_client.py) |
| `config.py` | Add `ai_provider`, `google_api_key`, `gemini_model`; make `anthropic_api_key` optional |
| `services/page_parser.py` | `ClaudeClient()` -> `get_ai_client()` |
| `services/work_analyzer.py` | Same |
| `services/example_generator.py` | Same |
| `services/feedback_generator.py` | Same |
| `requirements.txt` | Add `google-genai` |
| `.env` | Add `KVANTE_AI_PROVIDER`, `KVANTE_GOOGLE_API_KEY` |
| Tests | Update imports, add Gemini client tests |

### Not Changed

- Prompts — already model-agnostic
- Routers — no direct AI client usage
- Database models
- iOS app

### Error Handling Improvement

While refactoring, distinguish API errors (billing, auth, rate limits) from image-processing errors in the routers. Currently all exceptions surface as "take a clearer photo" which is misleading for API failures.

## Dependencies

- `google-genai` Python package
- Free Gemini API key from aistudio.google.com
