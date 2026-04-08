"""Verifier at AnimationStep accepterer visual=None for try-yours steps."""
from app.models.schemas import AnimationStep, VisualInstruction


def test_animation_step_accepts_none_visual():
    """Try-yours steps har visual=None — schema skal tillade det."""
    step = AnimationStep(
        step=9,
        phase="concrete",
        text="Nu er det din tur — kan du regne 7 × 9?",
        visual=None,
        audio_cue="Prøv selv",
    )
    assert step.visual is None
    assert step.text.startswith("Nu")


def test_animation_step_still_accepts_visual():
    """Eksisterende kode der sender visual fortsætter med at virke."""
    visual = VisualInstruction(type="single_digit_array", action="setup")
    step = AnimationStep(
        step=1,
        phase="concrete",
        text="Test",
        visual=visual,
        audio_cue="",
    )
    assert step.visual is not None
    assert step.visual.type == "single_digit_array"
