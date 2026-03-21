# Chat-First Redesign — Brainstorm

**Dato:** 2026-03-21
**Status:** Idéfase

## Kerneidé

Eleven skal opleve Kvante som en **samtale**, ikke et værktøj. Selv om interaktionen er styret (knapper, ikke fritekst), skal flowet føles som at chatte med en hjælper.

## Nuværende flow (tool-agtigt)
1. Scan side → se alle opgaver → vælg én → arbejd → scan svar → feedback
2. Føles som: åbn app → brug feature → luk app

## Ønsket flow (chat-agtigt)
1. Åbn app → "Hej! Skal vi kigge på dine opgaver?"
2. Scan ark (eller enkelt opgave) → opgaverne popper ind i chatten
3. Kvante nudger: "Hvad med at starte med 8b? Den passer godt til det du øvede sidst"
4. Eleven arbejder → scanner svar → feedback kommer som chat-bobler
5. "Fedt! Skal vi prøve den næste?" → naturlig overgang
6. Hele tiden mulighed for at se opgavearket og status (overlay/sidebar)

## Designprincipper

### 1. Chat som grundstruktur
- Alt præsenteres som beskeder i en chat-visning
- Kvante's beskeder = feedback, forslag, eksempler
- Elevens "beskeder" = scannede billeder + knapvalg
- Knapper er inline i chatten (ikke en separat toolbar)

### 2. Opgaveark som kontekst (ikke navigation)
- Opgavearket er altid tilgængeligt som et overlay eller pull-up
- Viser: hvilke opgaver er løst (✓), hvilken er aktiv (●), hvilke mangler (○)
- Fungerer som et progress-map, ikke som en menu
- Eleven kan tappe en opgave for at skifte fokus

### 3. Smart nudging
- Kvante foreslår næste opgave baseret på:
  - Sværhedsgrad (start let, byg op)
  - Fejlmønstre (hvis eleven kæmper med subtraktion, giv flere af dem)
  - Tid brugt (hvis eleven sidder fast, tilbyd hjælp)
- Altid som venlige forslag, aldrig tvang

### 4. Eksempler som visuelle oplevelser
- **Animerede step-by-step**: Tal der bevæger sig, tallinjer der tegnes
- **Praktiske eksempler**: "Forestil dig du har 17 æbler og giver 8 væk..."
- **Interaktive**: Eleven kan tappe for at se næste skridt (ikke alt på én gang)
- Research: Hvordan visualiserer man addition/subtraktion/multiplikation bedst for 9-13-årige?

## Tekniske overvejelser

### Chat-model
- Chat-historik er per session (ét opgaveark = én samtale)
- Beskeder har typer: system, kvante, elev_scan, elev_valg
- Scrollbar chat-view med nye beskeder i bunden
- Kamera-knap altid tilgængelig (som i en besked-app)

### Opgaveark-overlay
- Swipe up fra bunden for at se arket
- Eller lille floating indicator der viser "3/12 løst"
- Tryk for at se detaljer

### Animerede eksempler
- SwiftUI animationer for tal-bevægelser
- Lottie/Rive for mere komplekse animationer?
- Eller simpelt: skridt-for-skridt med fade-in og delays
- Research needed: Hvad virker bedst pædagogisk?

## Åbne spørgsmål

1. Skal man kunne have flere samtaler (flere opgaveark) aktive samtidig?
2. Hvor meget "personlighed" skal Kvante have i chatten?
3. Skal chatten gemmes mellem sessioner (så eleven kan se hvad de lavede i går)?
4. Hvordan håndterer vi at eleven scanner et nyt ark midt i en samtale?
5. Skal eksempel-animationer genereres af AI eller være pre-built templates?

## Research TODO

- [ ] Undersøg chat-UI patterns i edtech apps (Photomath, Socratic, Khan Academy)
- [ ] Undersøg animerede matematik-visualiseringer for børn
- [ ] Prototyp: simpel chat-view med hardcoded beskeder for at teste følelsen
- [ ] Pædagogisk research: nudging vs. fri navigation i læringsapps
