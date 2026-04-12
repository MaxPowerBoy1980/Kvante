# Feedback Sheet Design — Pakke 4 opfølgning

**Dato:** 2026-04-12
**Status:** Godkendt design, klar til implementation plan

## Problemet

Efter bulk-scan ser eleven kun grøn/orange markering på opgaverne i arket. Der er ingen reel feedback — ingen ros, ingen forklaring, ingen vurdering af processen. Tre separate sheets (FeedbackPreviewSheet, ErrorAnalysisSheet, AssignmentDetailSheet) giver fragmenteret og tynd oplevelse.

## Løsningen

Én samlet `FeedbackSheet` der erstatter alle tre sheets. Bruges overalt — tap på opgave i arket (aktiv session) og tap i matematikbogen (historisk). Layout er celebration-centreret med Kvante som afsender.

Kerneprincip: **Kvante er en venlig matematiklærer der ser processen, ikke bare facit.** Ros det gode, nudge det der kan blive bedre. Aldrig afslør svaret (kardinalreglen).

## Layout

`.large` presentation detent. ScrollView. Oppefra og ned:

### 1. Kvante pixelart (centreret, 64pt)

| Resultat | Pixelart | Findes |
|----------|----------|--------|
| Korrekt svar | `rob2_happy.png` | Ja |
| Procedural/careless fejl | `rob2.png` (neutral) | Ja |
| Forståelsesfejl | `rob2_sad.png` | Ja |
| 6/6 tandhjul | `rob2_surprised.png` | Ja |
| Loading | `rob2_thinking.png` | Ja |

Fremtidige pixelart (bestilles hos Max, ikke blokerende):
- `rob2_proud.png` — stolt, lysende øjne. Til 5-6 tandhjul.
- `rob2_encouraging.png` — opmuntrende, thumbs up. Til fejl med god proces.
- `rob2_examining.png` — undersøgende, forstørrelsesglas. Til loading/scanning.
- `rob2_teaching.png` — forklarende, lyspære. Til tips og forbedringsforslag.

### 2. Overskrift (centreret)

- **Korrekt:** "Rigtigt!" i grøn (`Color.green`), font weight 800, size 22
- **Procedural/careless fejl:** "Tæt på!" i orange (app primary), font weight 800, size 22
- **Forståelsesfejl:** "Ikke helt" i orange (app primary), font weight 800, size 22

Under overskriften: opgavetekst i muted grå, size 14. Format: `"347 + 285 — Opgave 3"`

### 3. Tandhjul-rating (centreret)

6 tandhjul-ikoner i en HStack med 8pt spacing. Fyldte tandhjul i orange (app primary), tomme i `Color(.systemGray5)`. Tekst-label ikke nødvendig — tandhjulene er selvforklarende.

Tandhjul-ikonet er et custom SwiftUI Shape eller en lille SVG/PNG der matcher Kvantes gear-krave fra pixelarten. Ikke SF Symbols.

### 4. Scan-billede

Elevens croppede arbejde vist i en rounded rectangle med 1pt border. Bruger eksisterende `ScanImageCache` + `BoundingBoxOverlay` når bounding box er tilgængelig. Fallback til fuldt scan-billede. Min height 120pt, max height 200pt, `scaledToFit`.

### 5. "Kvante siger" — feedback-sektion

Label: "KVANTE SIGER" i uppercase, size 12, font weight 600, muted grå.

Feedback-boble: teal baggrund (8% opacity), 12pt border radius, 14pt padding. LLM-genereret tekst, size 14, line height 1.5.

Indhold: Altid ros først ("Flot arbejde!", "Godt forsøg!"), derefter observation af processen. Ved fejl: peger på fejl-området uden at afsløre svaret.

### 6. "Tip fra Kvante" — forbedringsforslag (kun ved korrekt)

Label: "TIP FRA KVANTE" i uppercase, size 12, font weight 600, orange.

Tip-boble: varm hvid baggrund (`#FFF7ED`), 3pt orange venstre-border, 12pt border radius. LLM-genereret forbedringsforslag, size 14.

**Visningsregel:** Vises når opgaven er korrekt OG `improvement_tip` ikke er null. Ved 6/6 tandhjul vises tip aldrig — LLM'en instrueres til at returnere `improvement_tip: null` ved perfekt score, og iOS skjuler sektionen hvis feltet er null uanset.

### 7. Kvantes spørgsmål + svar-knapper (kun ved fejl)

Feedbacken fra sektion 5 slutter med et spørgsmål fra Kvante. Knapperne er elevens svar — det føles som en samtale, ikke kommandoer.

**Spørgsmålet er en fast skabelon valgt af fejltype — ikke LLM-genereret.** Dette sikrer konsistent tone og undgår kvalitetsproblemer. iOS vælger skabelon baseret på `error_type` fra bulk-scan-resultatet:

| Fejltype | Fast spørgsmålstekst |
|----------|---------------------|
| `procedural` | "Vil du prøve igen, eller skal jeg vise dig et eksempel med andre tal?" |
| `understanding` | "Skal jeg vise dig hvordan man løser den slags opgaver?" |
| `careless` | "Det var bare en lille glider — vil du prøve igen?" |

**Knapper:**
- **"Jeg prøver igen"** — stroked (border: 2pt orange, hvid baggrund). Lukker sheeten, eleven scanner nyt forsøg.
- **"Ja, vis mig!"** — filled (orange baggrund, hvid tekst). Lukker sheeten, navigerer til chatten med kontekst (se "Chat-kontekst ved Ja, vis mig!" nedenfor).

Ved `careless` fejl vises kun "Jeg prøver igen" som eneste knap — eleven behøver ikke hjælp, bare opmærksomhed.

**Kontekst-afhængig visning:** I aktive sessions (arket) vises spørgsmål + knapper. I matematikbogen (historisk review) vises hverken spørgsmål eller knapper — kun feedback-tekst og tandhjul. Eleven browser sit gamle arbejde, ikke løser opgaver.

### Chat-kontekst ved "Ja, vis mig!"

Når eleven tapper "Ja, vis mig!" sker følgende:

1. FeedbackSheet lukkes
2. iOS navigerer til chat-viewet med den pågældende assignment valgt som `currentAssignment`
3. iOS kalder `POST /sessions/{session_id}/assignments/{assignment_id}/example` — det eksisterende eksempel-endpoint der genererer et gennemregnet eksempel med andre tal
4. Chat-viewet viser Kvantes eksempel som en normal chat-besked med visual (stacked arithmetic, long multiplication, etc.)

Ingen ny backend-funktionalitet — det er det eksisterende eksempel-flow der trigges programmatisk i stedet for via chat-knap.

## Tandhjul-scoring

### 3 kriterier × 2 tandhjul = max 6

| Kriterie | 0 tandhjul | 1 tandhjul | 2 tandhjul |
|----------|-----------|-----------|-----------|
| **Rigtigt svar** | Forkert | — | Korrekt |
| **Synlig metode** | Ingen mellemregning vist | Noget arbejde vist | Alle trin tydeligt vist |
| **Notation** | Rodet/ulæseligt | Okay | Tydelig opstilling, mente markeret |

"Rigtigt svar" er binært (0 eller 2). "Synlig metode" og "Notation" er gradueret (0, 1, eller 2).

**Scoring-princip:** LLM'en scorer generøst — hellere 1 end 0 i tvivlstilfælde. En 9-årig der gentagne gange får 0 tandhjul stopper med at bruge appen.

**Lærer-override:** Backend gemmer LLM-scoren. Læreren kan override via lærer-dashboard (fremtidig feature). Feltet `teacher_gear_override: Optional[int]` reserveres i modellen.

### Backend: Ny prompt-instruktion

`analyze_work.txt`-prompten udvides til at returnere scoring:

```json
{
  "gear_score": {
    "correct_answer": 0 | 2,
    "visible_method": 0 | 1 | 2,
    "notation": 0 | 1 | 2
  },
  "improvement_tip": "string or null"
}
```

- `gear_score`: de tre kriterier. Summen er det samlede antal tandhjul (0-6).
- `improvement_tip`: konkret forbedringsforslag. Null hvis total == 6 eller hvis LLM'en ikke har noget konstruktivt.

`kvante_question` genereres IKKE af LLM'en — det er faste skabeloner valgt af `error_type` på iOS-siden (se sektion 7).

Eksisterende felter (`methodology_sound`, `errors`, `correct_elements`, `methodology_assessment`, `steps_identified`) bevares uændret.

### Validering af gear_score

Backend validerer LLM-output og clamper ugyldige værdier:
- `correct_answer`: skal være 0 eller 2. Hvis LLM returnerer 1, clamp til 2 (generøst). Hvis udenfor 0-2, clamp til nærmeste.
- `visible_method`: skal være 0, 1 eller 2. Clamp til [0, 2].
- `notation`: skal være 0, 1 eller 2. Clamp til [0, 2].
- Total sum valideres: max 6. Hvis LLM returnerer malformed JSON, fallback til `{"correct_answer": 2, "visible_method": 1, "notation": 1}` (generøs default = 4/6).

### GearScore Pydantic-model

```python
class GearScore(BaseModel):
    correct_answer: int = Field(ge=0, le=2, description="0=forkert, 2=korrekt (binært)")
    visible_method: int = Field(ge=0, le=2, description="0=ingen, 1=noget, 2=alle trin")
    notation: int = Field(ge=0, le=2, description="0=rodet, 1=okay, 2=tydelig")

    @computed_field
    @property
    def total(self) -> int:
        return self.correct_answer + self.visible_method + self.notation

    @field_validator("correct_answer")
    @classmethod
    def correct_answer_binary(cls, v: int) -> int:
        if v == 1:
            return 2
        return max(0, min(2, v))
```

### Hvornår genereres feedback?

**Opdelt i to lag for at undgå latency-problemer:**

**Lag 1 — Under bulk-scan (synkront):** `gear_score` og `improvement_tip` udtrækkes fra det eksisterende `analyze_work.txt`-kald. Det er ekstra struktureret output fra samme prompt, ikke et separat AI-kald. Latency-påvirkning: minimal — prompten returnerer lidt mere JSON.

**Lag 2 — Ved tap på opgave (lazy, on-demand):** Feedback-teksten ("Kvante siger") genereres først når eleven tapper på en opgave i FeedbackSheet. iOS kalder `POST /feedback/` med submission_id. Resultatet caches på Submission så gentagne taps er instant.

**Loading-state:** Når eleven åbner FeedbackSheet:
- Gear-score, overskrift, scan-billede og pixelart vises med det samme (data fra bulk-scan).
- "Kvante siger"-sektionen viser `rob2_thinking.png` + shimmer/skeleton mens feedback-tekst genereres (typisk 1-2 sekunder).
- Hvis feedback allerede er cached (eleven vender tilbage til en opgave): alt vises instant, ingen loading.

Denne opdeling holder bulk-scan hurtigt (20 opgaver påvirkes minimalt) og giver responsiv UI ved tap.

### Backend: Feedback-tekst

`give_feedback.txt`-prompten opdateres til at generere den samlede feedback-tekst der vises i "Kvante siger"-sektionen. Krav:

- Altid start med ros (selv ved fejl)
- Referer til synlige elementer i elevens arbejde
- Ved fejl: peg på fejl-området, aldrig svaret
- Ved korrekt: ros processen, nævn hvad der er godt
- 2-3 sætninger max
- Dansk, uformelt, varmt

## Migration: Alle indgangspunkter til gamle sheets

Før de tre gamle sheets slettes, skal alle indgangspunkter verificeres og omdirigeres:

1. **ArkCell.swift** — `onFeedbackTap` callback åbner FeedbackPreviewSheet eller ErrorAnalysisSheet afhængigt af status. → Omdirigér til FeedbackSheet.
2. **ArkCell.swift** — tap på done-opgave åbner FeedbackPreviewSheet. → Omdirigér til FeedbackSheet.
3. **AssignmentSheetView.swift** — `.sheet`-presentationer der binder til de gamle sheets. → Opdater bindings.
4. **NotebookWeekView.swift** (eller tilsvarende) — tap på historisk opgave åbner AssignmentDetailSheet. → Omdirigér til FeedbackSheet med `isHistorical: true`.

Implementation-test: byg appen, tap på ALLE opgave-tilstande (notStarted, inProgress, done) i arket OG i matematikbogen. Verificér at ingen navigation peger på de slettede sheets.

## Scope

### Med i denne feature
- `FeedbackSheet` SwiftUI view (erstatter FeedbackPreviewSheet, ErrorAnalysisSheet, AssignmentDetailSheet)
- Tandhjul-rating komponent (`GearRatingView`)
- Tandhjul-ikon som custom SwiftUI Shape
- Backend: udvidet `analyze_work.txt` prompt med `gear_score` og `improvement_tip`
- Backend: `GearScore` Pydantic-model med validering
- Backend: udvidet `give_feedback.txt` prompt
- iOS: faste spørgsmålsskabeloner baseret på `error_type` (ingen LLM-generering)
- Backend: nye felter på Submission/ArkAssignment response schemas
- Pixelart integration (de 5 eksisterende states)

### IKKE med i denne feature
- Streaks/gamification — separat TODO
- Lærer-override UI — backend-felt reserveres, UI kommer med lærer-dashboard
- Animations/transitions — besluttes i implementation plan
- "Ret mit svar"-flow (OCR-korrektion) — beholdes som separat ConfirmAnswerSheet
- Nye pixelart fra Max — nice-to-have, tilføjes senere

## Filer der berøres

### iOS (nye)
- `FeedbackSheet.swift` — den samlede feedback-visning
- `GearRatingView.swift` — tandhjul-rating komponent
- `GearShape.swift` — custom SwiftUI Shape for tandhjul-ikon

### iOS (ændres)
- `ArkCell.swift` — tap-handling peger nu på FeedbackSheet i stedet for FeedbackPreviewSheet/ErrorAnalysisSheet
- `NotebookWeekView.swift` / relevante notebook views — tap peger på FeedbackSheet i stedet for AssignmentDetailSheet
- `SessionViewModel.swift` — evt. nye felter for gear_score data

### iOS (slettes)
- `FeedbackPreviewSheet.swift`
- `ErrorAnalysisSheet.swift`
- `AssignmentDetailSheet.swift`

### Backend (nye)
- `app/models/schemas.py` — `GearScore` Pydantic-model med validering

### Backend (ændres)
- `app/prompts/analyze_work.txt` — tilføj `gear_score` og `improvement_tip` til prompt-instruktioner
- `app/prompts/give_feedback.txt` — opdater til ny feedback-stil (ros-først, uformelt dansk)
- `app/models/schemas.py` — nye felter på response-modeller (se nedenfor)
- `app/services/work_analyzer.py` — parse `gear_score` og `improvement_tip` fra AI-response med validering/clamping
- `app/services/bulk_scan_service.py` — inkluder gear_score i BulkSubmitResult
- `app/routers/bulk_submit.py` — returnér nye felter

### Backend (nye felter på eksisterende modeller)
- `BulkSubmitResult`: `gear_score: Optional[GearScore]`, `improvement_tip: Optional[str]`
- `SubmissionResponse`: `gear_score: Optional[GearScore]`, `improvement_tip: Optional[str]`
- `ArkAssignment`: `gear_score: Optional[GearScore]`, `improvement_tip: Optional[str]`
