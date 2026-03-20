import logging
import os
import tempfile

from app.logging_config import setup_logging


def test_setup_logging_creates_directory_and_file_handler():
    with tempfile.TemporaryDirectory() as tmpdir:
        setup_logging(log_level="INFO", log_dir=tmpdir)

        root = logging.getLogger()
        handler_types = [type(h).__name__ for h in root.handlers]
        assert "RotatingFileHandler" in handler_types

        log_file = os.path.join(tmpdir, "kvante.log")
        assert os.path.exists(log_file)

        # Clean up handlers to avoid affecting other tests
        root.handlers.clear()


def test_setup_logging_respects_debug_level():
    with tempfile.TemporaryDirectory() as tmpdir:
        setup_logging(log_level="DEBUG", log_dir=tmpdir)

        root = logging.getLogger()
        assert root.level == logging.DEBUG

        root.handlers.clear()


def test_setup_logging_creates_nested_directory():
    with tempfile.TemporaryDirectory() as tmpdir:
        nested = os.path.join(tmpdir, "sub", "dir")
        setup_logging(log_level="INFO", log_dir=nested)

        assert os.path.isdir(nested)
        assert os.path.exists(os.path.join(nested, "kvante.log"))

        logging.getLogger().handlers.clear()
