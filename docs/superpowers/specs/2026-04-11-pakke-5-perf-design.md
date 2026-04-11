# Pakke 5 Performance: Inline Assignments i Session-historik

**Dato:** 2026-04-11
**Problem:** Bog-arkivet laver 1 + N API-kald (N = antal sessions, typisk 30-40). Mærkbart langsomt på fysisk iPad over LAN.
**Løsning:** Udvid `GET /students/{id}/sessions` med `?include=assignments` så hele bogen kan hentes i ét request med 4 SQL queries.

## Backend

### Ny query-parameter

`GET /students/{student_id}/sessions?limit=0&include=assignments`

- `include` er optional, default `None`
- Uden parameteren: returnerer `SessionSummary` som i dag (bagudkompatibelt)
- Med `include=assignments`: returnerer `SessionSummaryWithAssignments` med fulde `ArkAssignment`-objekter

### Batch-query strategi

Når `include=assignments`:

1. **Query 1:** Alle sessions for studenten (som nu)
2. **Query 2:** Alle assignments for de fundne sessions — `WHERE session_id IN (:ids)`, ordnet efter position
3. **Query 3:** Alle submissions for de fundne sessions — `WHERE session_id IN (:ids)`, ordnet efter created_at
4. **Query 4:** Alle scanned_image chat messages for de fundne sessions — `WHERE session_id IN (:ids)`

Derefter bygges `ArkAssignment`-objekter i Python med samme logik som `get_session()`. Genbrug `_compute_ark_status()` og `_truncate_feedback()`.

### Nye Pydantic-schemas

```python
class SessionSummaryWithAssignments(SessionSummary):
    assignments: list[ArkAssignment]
    current_assignment_index: int
```

`SessionHistoryResponse` ændres ikke — den bruger allerede `list[SessionSummary]`, og `SessionSummaryWithAssignments` er en subclass.

### Backend N+1 fix (bonus)

Det eksisterende endpoint har intern N+1: looper over sessions og query'er assignments per session for at tælle dem. Fix dette samtidig — `assignment_count` og `completed_count` kan beregnes fra batch-queryen i stedet.

## iOS

### APIClient

Tilføj `include`-parameter på `getSessionHistory`:

```swift
func getSessionHistory(studentId: String, limit: Int = 20, include: String? = nil) async throws -> SessionHistoryResponse
```

Query-parameter tilføjes til URL'en kun når `include != nil`.

### Nye response-modeller

```swift
struct SessionSummaryWithAssignments: Codable {
    // Alle felter fra SessionSummary +
    let assignments: [ArkAssignment]
    let currentAssignmentIndex: Int
}
```

`SessionHistoryResponse` skal kunne decode begge typer. Simpleste tilgang: notebook-koden decoder med den udvidede type, andre call sites bruger den eksisterende.

### NotebookViewModel

- `loadSessions()` kalder `getSessionHistory(studentId:, limit: 0, include: "assignments")`
- Assignments er allerede i responsen — byg `NotebookSessionGroup` direkte
- Slet `loadDetail()`, `loadSessionGroups()` loop, og `detailCache`
- `sessionGroups(for:)` slår op i allerede-loaded data i stedet for at lave nye API-kald

### Hvad der ikke ændres

- `GET /sessions/{id}` forbliver uændret (bruges af ark-overlay og chat)
- Streak-data medtages ikke i batch-responsen (notebook bruger det ikke)
- `NotebookWeekView`, `NotebookSessionCard`, `AssignmentDetailSheet` — uændrede, modtager bare data hurtigere

## Test

- Pytest: test `include=assignments` returnerer assignments inline
- Pytest: test uden `include` returnerer `SessionSummary` uden assignments (bagudkompatibilitet)
- Pytest: test `assignment_count` og `completed_count` er korrekte med batch-query
- Manuel: åbn bog-arkivet på fysisk iPad, verificér hurtig load
