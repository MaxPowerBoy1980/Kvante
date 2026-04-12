# Ensartet feedback-oplevelse: enkelt-scan vs. bulk-scan

**Dato:** 2026-04-12
**Status:** Godkendt design

## Problemet

To forskellige scan-flows giver eleven to forskellige feedback-oplevelser:

| | Bulk-scan | Enkelt-scan |
|---|---|---|
| Gear score | AI beregner, returneres med det same | Ikke beregnet |
| Improvement tip | Returneret fra AI | Ikke returneret |
| Feedback i chat | Ikke relevant (bulk bruger ark) | Lazy via `POST /feedback/` (timeout-bug) |
| Tap i ark → | FeedbackSheet med alt data | FeedbackSheet med tomme felter |

## Design-beslutninger

1. **FeedbackSheet som primær fra arket, chat som fallback (C)** — tap i arket åbner altid FeedbackSheet med fuld data, uanset scan-type. Chat-flowet bevarer sin samtalefølelse med inline feedback.

2. **Gear score beregnes ved submission (A)** — `POST /submissions/` udvides til at kalde work_analyzer med scan-billedet. AI returnerer gear_score + improvement_tip i samme kald. **Latency-konsekvens:** dette tilføjer ~2-4 sekunder til det synkrone submissions-kald. Det er acceptabelt fordi (a) eleven allerede venter på OCR-resultatet, (b) chatten viser svar-bekræftelse ("Kvante læste: 735") med det samme fra compare_answer(), og gear-rating kan poppe ind bagefter som en separat chat-besked. Submission-response returnerer gear_score, men iOS behøver ikke blokere UI på det — vis resultat først, gear-rating når response er komplet.

3. **Erstat chat-feedback med gear_score data (C)** — i stedet for at kalde `POST /feedback/` efter forkert svar i chatten, vis gear_score + improvement_tip inline. Eliminerer den timeout'ende feedback-generator for enkelt-scan.

4. **improvement_tip vs. feedbackText** — improvement_tip er én konkret sætning ("Prøv at skrive mellemregninger tydeligt under hinanden"). Den gamle feedbackText var 2-3 sætninger med ros + observation + tip. I FeedbackSheet sammensættes en feedback-tekst fra gear_score-data: en åbningslinje baseret på gear_score.total (fx "Godt arbejde!" / "Tæt på!" / "Lad os prøve igen"), efterfulgt af improvement_tip. I chat vises improvement_tip alene — chatten har allerede kontekst fra svar-bekræftelsen.

## Arkitektur

### Flow 1: Enkelt-scan via chat

```
Elev scanner → Kamera → OCR/bekræft
  → POST /submissions/ (med scan-billede)
    → compare_answer() → korrekt/forkert
    → analyze_work() → gear_score + improvement_tip
    → returnér SubmissionResponse med gear_score + improvement_tip
  → Chat viser:
    - Korrekt: celebration + kompakt gear-rating + tip (hvis < 6/6)
    - Forkert: kompakt gear-rating + improvement_tip + "Prøv igen" / "Vis mig eksempel"
```

### Flow 2: Tap i arket (begge scan-typer)

```
Elev tapper opgave i ark
  → Ikke startet: navigér til chat (uændret)
  → Forkert (scannet): FeedbackSheet med gear_score + tip + scan-billede + knapper
  → Korrekt (done): FeedbackSheet historisk (ingen knapper)
  → Data populeret fra session detail response (som inkluderer gear_score for alle submissions)
```

## Backend-ændringer

### 1. `POST /submissions/` — tilføj work_analyzer

**Fil:** `backend/app/routers/submissions.py`

Efter `compare_answer()`, kald `analyze_work()` med scan-billedet og opgaveteksten:

```python
# Eksisterende: compare_answer()
is_correct = compare_answer(student_answer, assignment.correct_answer)

# Nyt: analyze_work() for gear_score
gear_score, improvement_tip = await analyze_work(
    image_bytes=image_bytes,
    assignment_text=assignment.text,
    correct_answer=assignment.correct_answer,
    student_answer=student_answer,
    is_correct=is_correct,
)
```

`analyze_work()` sender billedet til AI og beder om en struktureret vurdering med:
- `correct_answer` (0-2): Er svaret korrekt?
- `visible_method` (0-2): Er fremgangsmåden synlig?
- `notation` (0-2): Er notationen tydelig og organiseret?
- `improvement_tip` (str): Én konkret ting eleven kan forbedre.

Gem i `submission.analysis`:
```python
analysis["gear_score"] = gear_score.model_dump() if gear_score else None
analysis["improvement_tip"] = improvement_tip
```

**Fallback:** Hvis AI-kaldet fejler (timeout, parse-fejl), sæt gear_score = None. Submission lykkes stadig. Eleven ser sit resultat, bare uden rating.

### 2. `SubmissionResponse` schema

**Fil:** `backend/app/models/schemas.py`

Udvid med:
```python
class SubmissionResponse(BaseModel):
    # ... eksisterende felter ...
    gear_score: Optional[GearScore] = None
    improvement_tip: Optional[str] = None
```

### 3. Session detail returnerer gear_score

**Fil:** `backend/app/routers/practice.py`

`GET /sessions/{id}` bygger `SessionDetailResponse`. Populer `gear_score_by_assignment` og `improvement_tip_by_assignment` fra `submission.analysis` for alle submissions — ikke kun bulk-scan.

Logik: for hvert assignment med submission, læs `analysis.get("gear_score")` og `analysis.get("improvement_tip")`. Hvis flere submissions eksisterer (re-scan), brug den nyeste.

## iOS-ændringer

### 4. ChatViewModel — brug gear_score fra submission

**Fil:** `ios/Kvante/Kvante/ViewModels/ChatViewModel.swift`

**Korrekt svar:**
- Behold celebration (lyn-zigzag, haptik)
- Tilføj kompakt gear-rating (fx inline "⚙ 5/6") fra `submissionResponse.gearScore`
- Vis improvement_tip hvis gear_score.total < 6

**Forkert svar:**
- Vis kompakt gear-rating + improvement_tip
- Behold "Prøv igen" / "Vis mig eksempel" knapper
- **Fjern** kaldet til `apiClient.getFeedback(submissionId)` — al data kommer fra submission

### 5. SessionViewModel — populer gear data fra session detail

**Fil:** `ios/Kvante/Kvante/ViewModels/SessionViewModel.swift`

`loadSessionDetail()` populerer allerede `gearScoreByAssignment` fra bulk-scan resultater. Udvid til også at læse fra session detail response — som nu inkluderer gear_score for alle submissions.

FeedbackSheet modtager data via samme path som bulk. Ingen ændring i FeedbackSheet.swift nødvendig.

### 6. FeedbackSheet — fjern lazy loading

**Fil:** `ios/Kvante/Kvante/Views/Ark/FeedbackSheet.swift`

Fjern koden der kalder `POST /feedback/` on-demand. Al feedback-data er nu tilgængelig via session detail response ved åbning.

FeedbackSheet's "Kvante siger"-sektion sammensætter feedback fra gear_score-data:
- Åbningslinje baseret på `gear_score.total` (6: "Perfekt!", 4-5: "Godt arbejde!", 2-3: "Tæt på!", 0-1: "Lad os prøve igen")
- Efterfulgt af `improvement_tip` (hvis tilgængelig)
- Hvis hverken gear_score eller improvement_tip er tilgængelig: vis ingenting (tomt felt, ikke fallback-tekst)

## Berørte filer

| Fil | Ændring |
|-----|---------|
| `backend/app/routers/submissions.py` | Tilføj work_analyzer kald efter compare_answer |
| `backend/app/models/schemas.py` | Udvid SubmissionResponse med gear_score + improvement_tip |
| `backend/app/routers/practice.py` | Session detail populerer gear_score fra alle submissions |
| `backend/app/services/work_analyzer.py` | Evt. ny `analyze_single_submission()` funktion |
| `ios/.../ChatViewModel.swift` | Brug gear_score fra submission, fjern /feedback/ kald |
| `ios/.../SessionViewModel.swift` | Populer gear data fra session detail |
| `ios/.../FeedbackSheet.swift` | Fjern lazy feedback loading |
| `ios/.../Models/APIResponses.swift` | Udvid SubmissionResponse med gear_score + improvement_tip |

## Ikke i scope

- **`POST /feedback/` endpoint** — deprecated efter denne feature. Ingen iOS-path kalder den længere. Endpoint beholdes midlertidigt (ingen breaking change for evt. fremtidige klienter), men markeres med deprecation-kommentar i koden. Slettes i en fremtidig oprydningssprint. Timeout-buggen fikses ikke.
- **Scan-billede crop bug** — separat issue, ikke relateret til feedback-data.
- **Ændringer i bulk-scan flow** — allerede korrekt, ingen ændringer.
- **Chat-per-assignment refactor** — separat issue, uafhængig af feedback-ensretning.

## Testplan

- **Backend pytest:** `POST /submissions/` returnerer gear_score + improvement_tip for korrekt og forkert svar
- **Backend pytest:** `GET /sessions/{id}` inkluderer gear_score for enkelt-scan submissions
- **Backend pytest:** Submission lykkes med gear_score=None ved AI-fejl (fallback)
- **Manuel iOS:** Scan ét svar → se gear-rating i chat
- **Manuel iOS:** Scan ét forkert svar → tap i ark → FeedbackSheet med gear_score + tip
- **Manuel iOS:** Bulk-scan → FeedbackSheet uændret (regression)
