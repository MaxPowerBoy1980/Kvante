from pathlib import Path

import pytest

PROMPTS_DIR = Path(__file__).parent.parent / "app" / "prompts"

REQUIRED_PROMPTS = [
    "parse_page.txt",
    "generate_example.txt",
    "analyze_work.txt",
    "give_feedback.txt",
    "explain_method.txt",
]


@pytest.mark.parametrize("filename", REQUIRED_PROMPTS)
def test_prompt_file_exists_and_nonempty(filename):
    path = PROMPTS_DIR / filename
    assert path.exists(), f"Prompt file {filename} not found"
    content = path.read_text()
    assert len(content) > 100, f"Prompt file {filename} seems too short ({len(content)} chars)"


@pytest.mark.parametrize("filename", REQUIRED_PROMPTS)
def test_prompt_mentions_never_reveal_answer(filename):
    """Every prompt except parse_page must contain the 'never reveal answer' instruction."""
    if filename == "parse_page.txt":
        pytest.skip("parse_page doesn't analyze student work")
    content = (PROMPTS_DIR / filename).read_text().lower()
    assert "never" in content and "answer" in content, (
        f"Prompt {filename} must contain the 'never reveal answer' instruction"
    )
