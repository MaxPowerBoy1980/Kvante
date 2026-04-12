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

Vises kun når opgaven er korrekt OG LLM'en har et konkret forbedringsforslag. Kan udelades ved 6/6 tandhjul.

### 7. Kvantes spørgsmål + svar-knapper (kun ved fejl)

Feedbacken fra sektion 5 slutter med et spørgsmål fra Kvante. Knapperne er elevens svar — det føles som en samtale, ikke kommandoer.

**Spørgsmålet tilpasses fejltype:**

| Fejltype | Kvantes spørgsmål |
|----------|-------------------|
| Procedural | "Vil du prøve igen, eller skal jeg vise dig et eksempel med andre tal?" |
| Understanding | "Skal jeg vise dig hvordan man [regnearten]?" |
| Careless | "Det var bare en lille glider — vil du prøve igen?" |

**Knapper:**
- **"Jeg prøver igen"** — stroked (border: 2pt orange, hvid baggrund). Lukker sheeten, eleven scanner nyt forsøg.
- **"Ja, vis mig!"** — filled (orange baggrund, hvid tekst). Lukker sheeten, åbner chatten med Kvante der viser et gennemregnet eksempel med andre tal.

Ved careless fejl kan "Ja, vis mig!" erstattes af blot "Jeg prøver igen" som eneste knap — eleven behøver ikke hjælp, bare opmærksomhed.

**Kontekst-afhængig visning:** Knapperne vises kun i aktive sessions (arket). I matematikbogen (historisk review) vises feedback og tandhjul, men ingen handlingsknapper — eleven browser sit gamle arbejde, ikke løser opgaver.

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
  "improvement_tip": "string or null",
  "kvante_question": "string"
}
```

- `gear_score`: de tre kriterier. Summen er det samlede antal tandhjul.
- `improvement_tip`: konkret forbedringsforslag. Null hvis 6/6 eller hvis LLM'en ikke har noget konstruktivt.
- `kvante_question`: det afsluttende spørgsmål tilpasset fejltypen. Null ved korrekt svar.

Eksisterende felter (`methodology_sound`, `errors`, `correct_elements`, `methodology_assessment`, `steps_identified`) bevares uændret.

### Hvornår genereres feedback?

I dag genereres feedback on-demand via `POST /feedback/`. Med det nye design skal feedback genereres automatisk som del af bulk-scan flowet (`POST /sessions/{id}/bulk-submit`). Bulk-scan-servicen kalder allerede `analyze_work.txt` — den udvides til også at returnere `gear_score`, `improvement_tip` og `kvante_question`. Feedback-teksten ("Kvante siger") genereres i samme kald, ikke som separat request. Resultatet gemmes på Submission og returneres i BulkSubmitResult så iOS kan vise det med det samme uden ekstra API-kald.

### Backend: Feedback-tekst

`give_feedback.txt`-prompten opdateres til at generere den samlede feedback-tekst der vises i "Kvante siger"-sektionen. Krav:

- Altid start med ros (selv ved fejl)
- Referer til synlige elementer i elevens arbejde
- Ved fejl: peg på fejl-området, aldrig svaret
- Ved korrekt: ros processen, nævn hvad der er godt
- 2-3 sætninger max
- Dansk, uformelt, varmt

## Scope

### Med i denne feature
- `FeedbackSheet` SwiftUI view (erstatter FeedbackPreviewSheet, ErrorAnalysisSheet, AssignmentDetailSheet)
- Tandhjul-rating komponent (`GearRatingView`)
- Tandhjul-ikon som custom SwiftUI Shape
- Backend: udvidet `analyze_work.txt` prompt med `gear_score`, `improvement_tip`, `kvante_question`
- Backend: udvidet `give_feedback.txt` prompt
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

### Backend (ændres)
- `app/prompts/analyze_work.txt` — tilføj gear_score, improvement_tip, kvante_question
- `app/prompts/give_feedback.txt` — opdater til ny feedback-stil
- `app/models/schemas.py` — nye felter på response-modeller
- `app/services/work_analyzer.py` — parse nye felter fra AI-response
- `app/services/feedback_generator.py` — evt. tilpasninger
- `app/routers/bulk_submit.py` — inkluder gear_score i BulkSubmitResult

### Backend (nye felter på eksisterende modeller)
- `BulkSubmitResult`: `gear_score: dict`, `improvement_tip: Optional[str]`, `kvante_question: Optional[str]`
- `SubmissionResponse`: samme tre felter
- `ArkAssignment`: `gear_score: Optional[dict]`, `improvement_tip: Optional[str]`
