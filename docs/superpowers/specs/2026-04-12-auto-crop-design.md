# Auto-crop ved bulk-scan — Design Spec

**Dato:** 2026-04-12
**Status:** Godkendt
**Kontekst:** Pakke 4 opfølgning — bulk-scan returnerer i dag hele scan-siden som thumbnail. Denne feature tilføjer bounding boxes per opgave så ArkCell viser et meningsfuldt cropped billede af elevens arbejde.

## Kernebeslutninger

| Beslutning | Valg | Alternativ |
|-----------|-------|-----------|
| Tilgang | Udvid eksisterende Vision-prompt (ét API-kald) | Separat crop-pass (ekstra kald) |
| Bounding box dækning | Hele opgave-området (tekst + udregning + svar) | Kun svaret / to separate boxes |
| Visning i grid | Cropped thumbnail | Fuld side |
| Visning i detail sheets | Fuld side med highlighted bounding box | Kun crop |

## 1. Prompt-ændring

`backend/app/prompts/bulk_scan.txt` udvides. Hvert match-objekt returnerer en `bounding_box`:

```json
{
  "assignment_index": 0,
  "student_answer": "546",
  "confidence": 0.95,
  "page_index": 0,
  "error_type": null,
  "error_description": null,
  "bounding_box": [0.05, 0.22, 0.45, 0.18]
}
```

`bounding_box` er `[x, y, width, height]` normaliseret 0.0–1.0 relativt til sidens dimensioner. (0, 0) = øverste venstre hjørne.

Prompt-instruktion:
- "Estimate the bounding box that covers the full assignment area: printed problem text, handwritten work, and final answer"
- "Use normalized coordinates [x, y, width, height] where (0,0) is top-left and (1,1) is bottom-right"
- "If you cannot determine the region, omit bounding_box or set to null"

## 2. Backend-ændringer

### Submission.analysis

Udvides med:
- `bounding_box: [float, float, float, float] | null` — normaliserede koordinater

`page_index` er allerede der.

### BulkSubmitResult schema

Nyt felt:
- `bounding_box: list[float] | None = None`

### Parsing i bulk_submit.py

Læser `bounding_box` fra AI-response. Validering:
- Skal være en liste med 4 floats
- Alle værdier 0.0–1.0
- width > 0, height > 0
- Areal (width * height) < 0.80 af siden (afvis boxes der dækker næsten alt)
- Ugyldig/manglende → `null` (graceful fallback)

### Nyt endpoint: GET /scans/{id}/crop

**Query-parametre:** `x`, `y`, `w`, `h` (alle required floats 0.0–1.0), `padding` (optional float, default 0.15)

**Logik:**
1. Load original JPEG fra disk
2. Konverter normaliserede koordinater til pixel-koordinater
3. Udvid med padding i alle retninger (clamped til billedkanten)
4. Crop med Pillow
5. Returner JPEG (quality 85)

Fordel: iOS behøver ikke loade hele billedet for at vise en crop.

## 3. iOS-ændringer

### ArkCell

Når `bounding_box` er tilgængelig:
- Kalder crop-endpoint i stedet for fuld scan-image
- `ScannedImageView` får en ny optional `cropRegion: [Double]?` parameter
- Når `cropRegion` er sat, bruges crop-URL i stedet for standard scan-URL
- Fallback: ingen bounding_box → fuld side (status quo)

### ScanImageCache

- Cacher cropped billeder med key `"{scanId}_crop_{x}_{y}_{w}_{h}"`
- Eksisterende cache-logik for fuld-side billeder uændret

### ErrorAnalysisSheet / FeedbackPreviewSheet / AssignmentDetailSheet

Viser fuld side med highlight:
- Loader fuld scan-billede (som i dag)
- Overlay: semi-transparent dimming (sort 40% opacity) over hele billedet
- Un-dimmed rektangel over bounding box-området
- Tynd orange ramme (KvanteTheme.Colors.primary) omkring bounding box
- Effekt: elevens opgave "lyser op" mens resten af arket er tonet ned

### SessionViewModel

Udvides med:
- `boundingBox: [String: [Double]]` dictionary (assignment_id → [x, y, w, h])
- Populeres i `processBulkResult()` fra response

### BulkSubmitResponse iOS model

Tilføj:
- `boundingBox: [Double]?` på `BulkSubmitResult`

## 4. Fallback og edge cases

| Situation | Håndtering |
|-----------|-----------|
| Vision returnerer ingen bounding_box | `null` i analysis, iOS viser fuld side (status quo) |
| Bounding box > 80% af sidens areal | Backend afviser → sæt til null |
| Gamle submissions (før auto-crop) | Ingen bounding_box i analysis → fuld side |
| Multi-page scan | `page_index` + `bounding_box` kombineret — crop-endpoint modtager scan_id (peger på rigtig side) |
| Overlappende bounding boxes | Accepteres — hver celle viser sin egen crop |

## 5. Scope

### I scope
- Prompt-ændring med bounding_box
- Backend parsing + validering + crop-endpoint
- iOS crop-thumbnail i ArkCell
- iOS highlight-overlay i detail sheets
- Fallback for manglende/ugyldige boxes

### Ikke i scope
- Re-processing af gamle submissions
- Svar-specifik bounding box (kun hele opgave-området)
- Brugerjustering af bounding box
- Disk-caching af cropped billeder (kun NSCache in-memory)

## Berørte filer

### Backend
- `backend/app/prompts/bulk_scan.txt` — prompt-udvidelse
- `backend/app/routers/bulk_submit.py` — parsing + validering af bounding_box
- `backend/app/routers/scans.py` — nyt crop-endpoint
- `backend/app/models/schemas.py` — BulkSubmitResult + evt. CropQuery schema

### iOS
- `Kvante/Views/Ark/ArkCell.swift` — crop-thumbnail
- `Kvante/Views/Ark/ErrorAnalysisSheet.swift` — highlight-overlay
- `Kvante/Views/Ark/FeedbackPreviewSheet.swift` — highlight-overlay
- `Kvante/Views/Notebook/AssignmentDetailSheet.swift` — highlight-overlay (hvis scan vises)
- `Kvante/Services/ScanImageCache.swift` — crop-cache key
- `Kvante/Services/APIClient.swift` — crop-URL builder
- `Kvante/ViewModels/SessionViewModel.swift` — boundingBox dictionary
- `Kvante/Models/APIResponses.swift` — BulkSubmitResult model
- `Kvante/Views/Shared/ScannedImageView.swift` — cropRegion parameter

### Tests
- `backend/tests/test_bulk_submit.py` — bounding_box parsing + validering
- `backend/tests/test_scan_crop.py` — nyt crop-endpoint
