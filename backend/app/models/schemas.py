from pydantic import BaseModel


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
    visual: VisualInstruction
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
