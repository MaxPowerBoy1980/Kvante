# Pakke 5 — Bog-arkivet ("Din matematikbog")

**Dato:** 2026-04-09
**Status:** Design godkendt, klar til implementeringsplan

## Koncept

Matematikbogen er en samarbejdsbog mellem eleven og Kvante. Den viser alt elevens løste arbejde i et bogagtigt format med uge-kapitler, facit-kort og elevens scannede papirarbejde. Bogen er read-only — den er til refleksion og stolthed, ikke handling.

**Metafor:** "Den bog du og Kvante laver sammen." Eleven ejer sit arbejde, Kvante kommenterer og er til stede som figur. Begge navne på omslaget.

**Kerneværdi:** Eleven kan bladre tilbage og se sin udvikling — "i uge 10 kæmpede jeg med gange, i uge 14 kan jeg det."

## Navigationsflow

```
Home (NewHomeView)
  ↓ tap "Din matematikbog"-kort
  ↓ push SessionRoute.notebook

NotebookView (TabView .page style)
  ├── Tab 0: NotebookCoverView (omslag)
  ├── Tab 1: NotebookWeekView (nyeste uge)
  ├── Tab 2: NotebookWeekView (næstnyeste)
  └── ...osv (ældste sidst)
        ↓ tap facit-kort
        .sheet → AssignmentDetailSheet
```

- Swipe venstre/højre bladrer mellem omslag og uger
- Tap på facit-kort åbner detalje-sheet (ikke ny navigation)
- Tilbage-knap i header → pop til home
- Ny route: `SessionRoute.notebook` tilføjet eksisterende enum i ContentView

## Komponenter

### 1. Home-kort ("Din matematikbog")

Tredje kort på home-skærmen, under ugematematik- og øvelseskortet.

**Layout:**
- Venstre: mini-bogomslag (52×68 pt) med Kvante-figur, bogryg-gradient, "Matematikbogen" i miniature
- Midt: "Din matematikbog" (15pt semibold), "Lyng & Kvante — N opgaver løst" (12pt muted), kompakt statistik-række: "X uger" (teal) · "Y ✓" (grøn) · "Z ✗" (orange)
- Højre: chevron (›)

**Data:** Hentes fra eksisterende `getSessionHistory()` — tæl sessions, sum af completed/total assignments.

### 2. NotebookView

Container-view med `TabView(.page)`. Første tab er omslaget, resten er uger (nyeste først).

**State:** `@Observable NotebookViewModel` med:
- `weeks: [NotebookWeek]` — grupperede sessions pr. ISO-uge
- `totalSolved: Int` — samlet antal løste opgaver
- `totalCorrect: Int` — antal korrekte
- `totalIncorrect: Int` — antal forkerte
- `isLoading: Bool`

**NotebookWeek model:**
```swift
struct NotebookWeek: Identifiable {
    let id: Int                          // ISO uge-nummer
    let year: Int                        // år
    let dateRange: String                // "31. mar – 4. apr"
    let weeklySessions: [SessionDetail]  // ugentlige sæt
    let practiceSessions: [SessionDetail] // øvelser
    var solvedCount: Int                 // samlet løst denne uge
    var totalCount: Int                  // samlet opgaver denne uge
}
```

**Dataflow:**
1. Ved load: kald `GET /students/{id}/sessions` (alle, ikke limit 20)
2. Grupper sessions pr. ISO-uge baseret på `created_at`
3. Sortér uger nyeste først
4. Lazy-load sessionsdetaljer pr. uge: kald `GET /sessions/{id}` per session via `.task {}` i `NotebookWeekView.onAppear`. Cache resultater i ViewModel så re-swipe ikke re-fetcher. Brug eksisterende `getSessionDetail()`.

### 3. NotebookCoverView (omslag)

Statisk forside — vises som første tab i TabView.

**Layout (centreret, vertikalt):**
- Bogryg: subtil gradient (16pt bred) i venstre kant
- Kvante-figur: eksisterende KvanteFace (glad-udtryk) i ~90pt. Blyant som SVG-asset (`pencil-icon.svg` i Assets) placeret ved siden af figuren — simplere end SwiftUI Path for en statisk illustration uden animationsbehov.
- Titel: "Matematikbogen" (22pt bold, ink)
- Undertitel: "[Elevnavn] & Kvante" (15pt, ink 60% opacity)
- Bryst-panel-prikker: 5 prikker (4 blå + 1 orange midt) som dekoration
- Badge: "N opgaver løst" (teal baggrund, hvid tekst, rounded pill)
- Swipe-hint: "swipe for at bladre ›" (12pt, ink 30% opacity) i bunden

**Baggrund:** cream (#FDFBF7) med papir-tekstur (samme seeded noise som AssignmentSheetView, 4% opacity).

### 4. NotebookWeekView (uge-side)

Én uge med alle opgaver som facit-kort.

**Header:**
- Ugenummer: "Uge 14" (20pt bold)
- Datoer: "31. mar – 4. apr" (12pt, muted) — højrestillet
- Progress: "6 af 6 opgaver løst" (13pt, teal semibold)

**Ugentligt sæt (øverst):**
Vertikalt scroll med facit-kort for hver assignment i ugentlige sessions.

**Ekstra øvelser (nederst, hvis nogen):**
Divider-label: "Ekstra øvelser" (11pt, uppercase, muted)
Facit-kort for alle practice-session assignments fra denne uge.

**Facit-kort design:**
- Baggrund: hvid, 12pt rounded corners, subtil border
- Top-række: opgavetekst (15pt semibold, venstre) + svar-badge (højre)
  - Korrekt: grøn badge "✓ [svar]"
  - Forkert: orange badge "✗ [elevens svar]"
  - Ikke løst: grå badge "—"
- Bund-række: én linje AI-feedback (12pt, ink 50%)
- Tap → åbn AssignmentDetailSheet

**Bogryg:** Samme gradient som omslaget i venstre kant.

**Page indicator:** Ved under 10 uger: standard page dots (orange aktuel, grå rest). Ved 10+ uger: tekst-label "Uge 14 af 22" i stedet for dots — 22 dots er visuelt ubrugeligt.

### 5. AssignmentDetailSheet

.sheet() der vises ved tap på facit-kort. Ikke navigation — forbliv i bogen.

**Layout (ScrollView-wrapped, vertikalt):**
Hele indholdet wrappes i ScrollView for at håndtere lange feedback-tekster + scan-billede på mindre skærme (SE, mini).

- Drag handle (standard iOS)
- Label: "Opgave N · Uge M" (11pt, uppercase, muted)
- Opgavetekst: stort (24pt bold, ink)
- Resultat-sektion:
  - Korrekt: "Dit svar: [svar] ✓" (grøn, 20pt)
  - Forkert: to kolonner — "Dit svar: [svar]" (orange) + "Rigtigt svar: [svar]" (grøn)
  - Ikke løst: "Ikke besvaret" (muted)
- Scannet billede: elevens papirarbejde fra `GET /scans/{id}/image` i en hvid rounded container. Brug eksisterende `ScanImageCache` til at loade. Placeholder med kamera-ikon hvis ingen scan.
- Kvantes feedback: teal baggrund (8% opacity), rounded corners, mini-Kvante figur (20pt) øverst til venstre, fuld feedback-tekst (13pt, ink). Brug `latest_ai_feedback_summary` fra ArkAssignment.
- Dato: completion-dato (11pt, muted, centreret)

## Backend-ændringer

Minimale — to udvidelser af eksisterende endpoints.

### 1. Fjern limit på session-historik

`GET /students/{id}/sessions` returnerer i dag maks 20. Bogen skal vise alt.

**Ændring:** Gør limit konfigurerbar med query parameter `?limit=0` for alle. Default forbliver 20 (home bruger stadig default). Alternativt: nyt dedikeret notebook-endpoint, men overkill.

### 2. Tilføj answer-felter til ArkAssignment

`GET /sessions/{id}` returnerer `ArkAssignment` uden elevens svar eller korrekt svar. Facit-kortet behøver begge.

**Tilføj til ArkAssignment-schema:**
```python
correct_answer: str | None    # Fra Assignment.correct_answer
student_answer: str | None    # Fra seneste Submission.analysis["student_answer"] (bekræftet felt-navn)
```

**Hentes fra:** Assignment-tabellen har `correct_answer`. Seneste Submission's `analysis` JSON indeholder student_answer (den allerede hentes for `latest_ai_feedback_summary`).

## Design-system

Al styling følger eksisterende KvanteTheme:

| Element | Stil |
|---------|------|
| Baggrund | cream (#FDFBF7) med papir-tekstur |
| Bogryg | Linear gradient #e8ddd0 → cream, 16pt bred, venstre kant |
| Facit-kort | Hvid, cardRadius (24pt reduceret til 12pt for kompakthed), cardBorder |
| Korrekt-badge | success (#4CAF50) baggrund, hvid tekst |
| Forkert-badge | primary (#E85D26) baggrund, hvid tekst |
| Feedback-tekst | ink 50% opacity, 12pt |
| Kvante-figur | Eksisterende KvanteFace med .happy expression |
| Page dots | 6pt cirkler, primary for aktuel, ink 15% for rest |

## Nye filer

### iOS
| Fil | Placering | Formål |
|-----|-----------|--------|
| NotebookView.swift | Views/Notebook/ | TabView container + back-navigation |
| NotebookCoverView.swift | Views/Notebook/ | Omslag med Kvante + stats |
| NotebookWeekView.swift | Views/Notebook/ | Uge-side med facit-kort |
| AssignmentDetailSheet.swift | Views/Notebook/ | Detalje-sheet ved tap |
| NotebookViewModel.swift | ViewModels/ | Data-loading, uge-gruppering, caching |

### Backend
Ingen nye filer — ændringer i eksisterende:
| Fil | Ændring |
|-----|---------|
| `app/models/schemas.py` | Tilføj `correct_answer`, `student_answer` til ArkAssignment |
| `app/routers/practice.py` | Tilføj answer-felter i session-detail query + konfigurerbar limit |

## Afgrænsninger

- **Read-only.** Ingen handlinger fra bogen — ingen "prøv igen", ingen scan, ingen chat.
- **Ingen bulk-scan.** Pakke 4 bygger det; bogen viser automatisk resultaterne når de findes.
- **Ingen statistik-side.** Omslaget viser samlet antal. Dybere analytics er en fremtidig feature.
- **Ingen deling/eksport.** Ingen PDF, ingen print, ingen send-til-lærer. Kan tilføjes senere.
- **Ingen offline-cache.** Bogen loader fra API hver gang. Kan optimeres senere med lokal cache.
- **N+1 queries accepteret i v1.** Lazy-load pr. uge giver N+1 waterfall ved hurtig swipe. Acceptabelt med cache i ViewModel (re-swipe gratis). Fremtidig optimering: backend returnerer assignments[] inline i session-listen ved `?include=assignments`, så én request dækker hele bogen.
- **Elevnavn:** Brug eksisterende onboarding-navn fra UserDefaults/local storage.

## Accessibility

| Element | Label |
|---------|-------|
| Home bog-kort | "Din matematikbog. N opgaver løst" |
| Omslag | "Matematikbogen. [Elevnavn] og Kvante. N opgaver løst" |
| Facit-kort (korrekt) | "Opgave: [tekst]. Dit svar: [svar]. Rigtigt." |
| Facit-kort (forkert) | "Opgave: [tekst]. Dit svar: [svar]. Forkert. Rigtigt svar: [svar]." |
| Facit-kort (ikke løst) | "Opgave: [tekst]. Ikke besvaret." |
| Uge-side | "Uge [N]. [X] af [Y] opgaver løst." |
| Page indicator | "Side [N] af [M]" |
| Scannet billede | "Dit håndskrevne arbejde" |
| Kvantes feedback | "Kvante siger: [feedback-tekst]" |

KvanteFace har allerede `accessibilityLabel` — genbrug det. Facit-kort og uge-sider markeres som `accessibilityElement` med samlet label så VoiceOver læser dem som én enhed.

## Edge cases

| Case | Håndtering |
|------|-----------|
| Ingen sessions endnu | Omslag viser "0 opgaver løst", ingen uge-tabs. Kvante ser neutral ud. |
| Session uden completions | Ugen vises med grå "—" badges. Feedback-linje: "Ikke besvaret endnu" |
| Session uden scan | Detalje-sheet viser placeholder med kamera-ikon i stedet for billede |
| Mange uger (20+) | TabView med lazy loading. Performance er fin — hver uge er let view. |
| Uge med kun øvelser | Ingen "Ugentligt sæt"-sektion, kun "Ekstra øvelser" |
| Uge med kun ugentligt | Ingen "Ekstra øvelser"-sektion |
| Forkert svar uden correct_answer i DB | Vis kun elevens svar med orange badge, ingen "rigtigt svar"-kolonne |
