from typing import Literal

from pydantic import BaseModel, SerializeAsAny, field_validator


# --- Page Scan ---

class ParsedAssignment(BaseModel):
    id: str
    local_id: str
    text: str
    type: str
    topic: str
    difficulty_estimate: int
    position_on_page: str


class PageScanResponse(BaseModel):
    session_id: str
    assignments: list[ParsedAssignment]
    page_context: str
    suggested_order: list[str]
    suggested_start: str
    reasoning: str
    detected_language: str


# --- Example Generator ---

class VisualInstruction(BaseModel):
    type: str       # object_collection, number_line, array_grid, grouping, pie_chart, bar_model, coordinate_grid, equation
    action: str     # type-specific action (draw, cross_out, jump_forward, etc.)

    model_config = {"extra": "allow"}  # Type-specific flat fields pass through


class AnimationStep(BaseModel):
    step: int
    phase: str          # concrete, semi-concrete, abstract
    text: str
    visual: VisualInstruction | None = None
    audio_cue: str = ""


class ExampleResponse(BaseModel):
    example_problem: str
    pedagogy: str = "concrete-first"
    steps: list[AnimationStep]
    note: str = ""


# --- Work Analyzer (Submission) ---

class AnalysisStep(BaseModel):
    step: int
    description: str
    correct: bool


class SubmissionResponse(BaseModel):
    submission_id: str
    assignment_id: str
    session_id: str
    student_answer: str
    correct_answer: str = ""
    methodology_sound: bool
    steps_identified: list[AnalysisStep]
    errors: list[str]
    correct_elements: list[str]
    methodology_assessment: str
    handwriting_note: str = ""
    confidence: float


# --- Feedback ---

class StructuredPrompt(BaseModel):
    id: str
    label: str


class FeedbackResponse(BaseModel):
    feedback_text: str
    tone: str
    structured_prompts: list[StructuredPrompt]


class FeedbackRequest(BaseModel):
    submission_id: str
    language: str = "da"


class FollowupRequest(BaseModel):
    action: str  # explain_different | another_example | show_first_step | what_did_well | try_again | explain_task


# --- Health ---

class HealthResponse(BaseModel):
    status: str
    version: str


# --- Errors ---

class ErrorResponse(BaseModel):
    error: str
    message: str
    student_message: str = ""
    detail: str = ""


# --- Scans ---

class ScanUploadResponse(BaseModel):
    scan_id: str


# --- Chat Persistence ---

class ChatMessageCreate(BaseModel):
    sender: str
    content_type: str
    content: dict
    assignment_id: str | None = None


class ChatMessageOut(BaseModel):
    id: str
    session_id: str
    assignment_id: str | None
    sender: str
    content_type: str
    content: dict
    created_at: str


class SaveMessagesRequest(BaseModel):
    session_id: str
    messages: list[ChatMessageCreate]


class SaveMessagesResponse(BaseModel):
    saved_count: int


class LoadMessagesResponse(BaseModel):
    session_id: str
    messages: list[ChatMessageOut]


# --- Weekly Assignments ---

class WeeklyRequest(BaseModel):
    student_id: str
    grade_level: int = 4
    count: int = 6


class SessionSummary(BaseModel):
    session_id: str
    name: str
    mode: str
    topic: str | None
    status: str
    assignment_count: int
    completed_count: int
    created_at: str
    completed_at: str | None


class SessionHistoryResponse(BaseModel):
    sessions: list[SerializeAsAny[SessionSummary]]


class SessionSummaryWithAssignments(SessionSummary):
    """SessionSummary with inline ArkAssignment objects (used by notebook)."""
    assignments: list["ArkAssignment"]
    current_assignment_index: int


# --- Ark Overlay (Pakke 2a) ---

class ArkAssignment(BaseModel):
    id: str
    local_id: str
    text: str
    type: str
    topic: str
    difficulty_estimate: int
    position: int

    ark_status: Literal["not_started", "in_progress", "done"]
    latest_scan_id: str | None = None
    latest_ai_feedback_summary: str | None = None
    teacher_comment: str | None = None
    correct_answer: str | None = None
    student_answer: str | None = None

    @field_validator("teacher_comment", mode="before")
    @classmethod
    def normalize_empty_to_none(cls, v: str | None) -> str | None:
        if isinstance(v, str) and v.strip() == "":
            return None
        return v


class SessionDetailResponse(BaseModel):
    session_id: str
    session_name: str
    current_assignment_index: int
    assignments: list[ArkAssignment]
    streak: "StreakResponse | None" = None


# --- Bulk Scan (Pakke 4) ---

class BulkSubmitResult(BaseModel):
    assignment_id: str
    assignment_text: str
    student_answer: str | None
    status: Literal["correct", "incorrect", "uncertain", "not_found"]
    error_type: Literal["procedural", "understanding", "careless"] | None = None
    error_description: str | None = None
    confidence: float
    page_index: int | None = None
    submission_id: str | None = None
    bounding_box: list[float] | None = None


class BulkSubmitSummary(BaseModel):
    total: int
    correct: int
    incorrect: int
    uncertain: int
    not_found: int


class BulkSubmitResponse(BaseModel):
    session_id: str
    results: list[BulkSubmitResult]
    summary: BulkSubmitSummary
    scan_ids: list[str]


# --- Streak (Pakke 2b PR2) ---

class StreakResponse(BaseModel):
    current_streak: int
    longest_streak: int
    last_active_date: str | None  # ISO date in student's locale, or None if never active
