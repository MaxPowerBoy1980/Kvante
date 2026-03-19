import io

import cv2
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

from app.config import settings

MAX_DIMENSION = 1568


def _validate_size(image_bytes: bytes) -> None:
    if len(image_bytes) > settings.max_upload_size:
        raise ValueError(
            f"Image size ({len(image_bytes)} bytes) exceeds maximum "
            f"({settings.max_upload_size} bytes)"
        )


def _resize_if_needed(img: Image.Image) -> Image.Image:
    w, h = img.size
    if max(w, h) <= MAX_DIMENSION:
        return img
    scale = MAX_DIMENSION / max(w, h)
    new_w, new_h = int(w * scale), int(h * scale)
    return img.resize((new_w, new_h), Image.LANCZOS)


def _to_jpeg_bytes(img: Image.Image) -> bytes:
    if img.mode == "RGBA":
        img = img.convert("RGB")
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


def preprocess_textbook_page(image_bytes: bytes) -> bytes:
    """Light preprocessing for printed textbook pages.

    Resize to max 1568px, light contrast enhancement.
    """
    _validate_size(image_bytes)
    img = Image.open(io.BytesIO(image_bytes))
    img = _resize_if_needed(img)
    img = ImageEnhance.Contrast(img).enhance(1.2)
    return _to_jpeg_bytes(img)


def preprocess_handwritten_work(image_bytes: bytes) -> bytes:
    """Aggressive preprocessing for pencil-on-paper handwritten work.

    Grayscale -> CLAHE -> sharpen -> resize.
    Critical for faint pencil marks.
    """
    _validate_size(image_bytes)
    img = Image.open(io.BytesIO(image_bytes))
    img = _resize_if_needed(img)
    img = img.convert("L")

    # CLAHE via OpenCV for better pencil contrast
    arr = np.array(img)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    arr = clahe.apply(arr)
    img = Image.fromarray(arr)

    # Light sharpening
    img = img.filter(ImageFilter.UnsharpMask(radius=1.5, percent=50, threshold=3))

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()
