import io
from PIL import Image
import pytest

from app.services.image_preprocessor import preprocess_textbook_page, preprocess_handwritten_work


def _make_test_image(width: int = 3000, height: int = 4000, mode: str = "RGB") -> bytes:
    """Create a test image as bytes."""
    img = Image.new(mode, (width, height), color="white")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_textbook_page_resizes_to_max_1568():
    raw = _make_test_image(3000, 4000)
    result = preprocess_textbook_page(raw)
    img = Image.open(io.BytesIO(result))
    assert max(img.size) <= 1568


def test_textbook_page_returns_jpeg():
    raw = _make_test_image()
    result = preprocess_textbook_page(raw)
    img = Image.open(io.BytesIO(result))
    assert img.format == "JPEG"


def test_handwritten_work_converts_to_grayscale():
    raw = _make_test_image(mode="RGB")
    result = preprocess_handwritten_work(raw)
    img = Image.open(io.BytesIO(result))
    assert img.mode == "L"


def test_handwritten_work_resizes():
    raw = _make_test_image(3000, 4000)
    result = preprocess_handwritten_work(raw)
    img = Image.open(io.BytesIO(result))
    assert max(img.size) <= 1568


def test_small_image_not_upscaled():
    raw = _make_test_image(800, 600)
    result = preprocess_textbook_page(raw)
    img = Image.open(io.BytesIO(result))
    assert max(img.size) <= 800


def test_rejects_oversized_input():
    # Create a ~12 MB image (exceeds 10 MB limit)
    huge = _make_test_image(8000, 8000)
    if len(huge) <= 10 * 1024 * 1024:
        pytest.skip("Test image not large enough to exceed limit")
    with pytest.raises(ValueError, match="exceeds maximum"):
        preprocess_textbook_page(huge)
