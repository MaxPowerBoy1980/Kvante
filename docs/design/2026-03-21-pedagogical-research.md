# Pædagogisk Research: Matematik-eksempler for 9-13 årige

**Kilde:** Google Deep Research, 21. marts 2026

---

## De 6 vigtigste fund for Kvante

### 1. Alternating Pairs — eksempel → opgave → eksempel → opgave
- Vis et fuldt gennemregnet eksempel (f.eks. 17 + x = 25)
- Derefter straks en lignende opgave med andre tal (12 + x = 30)
- Eleven anvender logikken mens den stadig er frisk i arbejdshukommelsen

### 2. Backwards Fading — fjern gradvist trin
- Problem 1: Fuldt eksempel (alle trin vist)
- Problem 2: Kun sidste trin mangler
- Problem 3: Sidste to trin mangler
- Problem 4-5: Eleven løser helt selv
- **Krav:** Kun avancér efter 3 korrekte i træk (mastery)

### 3. Tallinje over cirkeldiagrammer
- Tallinjer er overlegne til brøker, decimaler og procent
- Viser magnitude (størrelse) som afstand — ikke "stykker af en kage"
- Kan animeres: "zoom ind" mellem hele tal for at vise decimaler
- Cirkelmodeller fejler ved brøker > 1 (f.eks. 5/4)

### 4. Singapore Bar Model til tekstopgaver
- Eleven trækker blokke for at bygge en model FØR de skriver ligningen
- Part-Whole bars: addition/subtraktion
- Comparison bars: forskel/ratio
- Naturlig overgang til algebra (den ukendte del → variabel x)

### 5. Tap-to-Reveal med mikro-prompts
- Vis ét trin ad gangen — IKKE hele løsningen
- Eleven skal besvare et kort spørgsmål for at se næste trin:
  - "Hvad var målet med dette trin?"
  - "Hvorfor trak vi 5 fra begge sider?"
- Forebygger "mindless scrolling" og tvinger aktiv tænkning

### 6. Bland manipulatives — undgå distraherende billeder
- Brug simple geometriske former (disks, bars, tiles) — IKKE realistiske æbler/pizza
- Realistiske billeder distraherer fra den matematiske struktur
- Hold "den ukendte" i en konsistent farve (f.eks. altid orange) gennem hele appen

---

## Cognitive Load Theory — kort opsummering

| Type | Beskrivelse | Strategi |
|------|-------------|----------|
| **Intrinsic** | Opgavens iboende sværhed | Worked examples der dekonstruerer |
| **Extraneous** | Mentalt arbejde på irrelevante elementer | Simpelt UI, ingen pynt |
| **Germane** | Produktivt arbejde med at bygge forståelse | Self-explanation prompts |

**Expertise Reversal Effect:** Når eleven mestrer et emne, bliver eksempler en belastning. Appen SKAL adaptere og skifte til selvstændig problemløsning.

---

## Selvforklaring (Self-Explanation Effect)

Elever der forklarer trinene for sig selv scorer markant højere. Implementér som:
- **Multiple choice:** "Hvorfor trak vi 5 fra begge sider?" → "For at isolere x" / "Fordi 5 er mindre end 8"
- **Find fejlen:** Vis et eksempel med en typisk fejl → eleven finder den
- Kvaliteten af forklaringen tæller — link til matematisk princip, ikke bare genfortælling

---

## Konkret → Ikonisk → Symbolsk (Concreteness Fading)

1. **Konkret:** "Du har 17 æbler og giver 8 væk" (med simple disks, ikke realistiske æbler)
2. **Ikonisk:** Bar model eller tallinje der viser 17 - 8
3. **Symbolsk:** 17 - 8 = ___

Appen bør starte konkret og fade til symbolsk over tid.

---

## Animation vs. Statiske Billeder

- **Animationer** virker for dynamiske processer (rotation, lang division)
- **Risiko:** "Transience effect" — information forsvinder før eleven har processeret den
- **Løsning:** Eleven SKAL kunne pause, spole tilbage, gentage
- **Statiske billeder** er bedre for komplekse multi-trin procedurer (alle trin synlige samtidig)
- **"Illusion of understanding":** Animation kan føles som forståelse uden at være det → par med self-explanation

---

## Eksisterende apps — hvad virker

| App | Styrke | Kvante kan lære |
|-----|--------|----------------|
| **Photomath** | Granulære trin, farve-fokus på aktiv del | Step-by-step med sub-steps on demand |
| **Khanmigo** | Sokratisk: "Hvad tror du næste trin er?" | Aldrig giv svaret, stil spørgsmål |
| **Brilliant** | Interaktive simulationer, ingen videoer | "Learn by doing" — sliders, manipulatives |
| **Mathigon** | Progressive disclosure, virtuel tutor | Små bidder, løs puzzle før næste afsnit |
| **Duolingo Math** | Micro-lessons (< 5 min), streaks | Bite-sized, daglig vane |

---

## Dansk kontekst — Fælles Mål

### Klassetrin og emner

| Klasse | Tal og Algebra | Geometri |
|--------|---------------|----------|
| 3. | Naturlige tal til 10.000, simpel hovedregning | Spejlsymmetri, grundformer |
| 4. | Brøker som dele af helhed, lang division | Areal af rektangler, vinkler |
| 5. | Decimaler og relation til brøker | 3D-former, koordinatsystem |
| 6. | Procent og rente, simple ligninger (x+5=12) | Transformationer, sandsynlighed |

### Kompetenceområder
- **Problembehandling:** Åbne og lukkede problemer
- **Modellering:** Oversæt virkelighed til matematik og tilbage
- **Ræsonnement:** Forklar "hvorfor", ikke bare "hvad"
- **Repræsentation:** Vælg bedste fremstilling (tabel, graf, ligning)

### Dansk terminologi
- Brug "tæller" og "nævner" for brøker
- Hverdagsmatematik-scenarier: budget til klassefest, areal af fodboldbane

---

## Implementeringsanbefalinger for Kvante

1. **Alternating pairs** som standard-flow for eksempler
2. **Backwards fading** med mastery-gate (3 korrekte i træk)
3. **Tallinje** som primært visuelt værktøj for rationelle tal
4. **Bar model** builder til tekstopgaver (drag-and-drop)
5. **Tap-to-reveal** med self-explanation mikro-prompts
6. **Enkelt visuelt design** — ingen distraherende dekorationer
7. **Konsistent farvekodning** — ukendt altid i samme farve
8. **Adaptivt niveau** — skift fra eksempler til selvstændig løsning ved mastery
9. **Dansk terminologi** og hverdagsscenarier fra Fælles Mål
