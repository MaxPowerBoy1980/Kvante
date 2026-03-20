# Kvante launchd Autostart and Logging — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a macOS launchd system daemon for autostart and structured file-based logging with configurable verbosity.

**Architecture:** A new `logging_config.py` module configures Python's `logging` with a `RotatingFileHandler` writing to `~/Library/Logs/Kvante/kvante.log` plus a console handler. The existing `logging.basicConfig()` in `main.py` is replaced. A launchd plist at `/Library/LaunchDaemons/com.kvante.backend.plist` runs the backend at boot. Two new settings (`log_level`, `log_dir`) are added to `config.py`.

**Tech Stack:** Python `logging` stdlib, `RotatingFileHandler`, macOS launchd, pydantic-settings

**Spec:** `docs/superpowers/specs/2026-03-20-kvante-launchd-logging.md`

---

## File Structure

- **Create:** `backend/app/logging_config.py` — `setup_logging()` function
- **Create:** `backend/com.kvante.backend.plist` — launchd plist (committed to repo)
- **Modify:** `backend/app/config.py` — add `log_level` and `log_dir` settings
- **Modify:** `backend/app/main.py` — replace `basicConfig` with `setup_logging()`, add startup summary
- **Modify:** `backend/app/services/ai_client.py` — add timing to `send_text`/`send_vision`, debug payloads
- **Modify:** `backend/app/services/page_parser.py` — add timing around `parse_page`
- **Modify:** `backend/app/services/work_analyzer.py` — add timing around `analyze_work`
- **Modify:** `backend/app/services/example_generator.py` — add timing around `generate_example`
- **Modify:** `backend/app/services/feedback_generator.py` — add timing around `generate_feedback`/`generate_followup`
- **Modify:** `backend/app/services/image_preprocessor.py` — add logger, debug logging for preprocessing steps
- **Modify:** `backend/app/routers/health.py` — add logger
- **Modify:** `backend/app/routers/assignments.py` — add logger
- **Modify:** `backend/app/routers/feedback.py` — add logger
- **Modify:** `backend/.env.example` — add `KVANTE_LOG_LEVEL` and `KVANTE_LOG_DIR`
- **Modify:** `backend/tests/conftest.py` — set `KVANTE_LOG_DIR` to temp path for test portability
- **Create:** `backend/tests/test_logging_config.py` — tests for the logging setup

---

### Task 1: Add log_level and log_dir to config.py and .env.example

**Files:**
- Modify: `backend/app/config.py:5-19`
- Modify: `backend/.env.example`

- [ ] **Step 1: Add the two new settings**

In `backend/app/config.py`, add `log_level` and `log_dir` to the `Settings` class, after the existing `prompts_dir` field:

```python
    log_level: str = "INFO"  # INFO or DEBUG
    log_dir: str = "/Users/oleserver/Library/Logs/Kvante"  # absolute path; ~ not expanded
```

- [ ] **Step 2: Add entries to .env.example**

Append to `backend/.env.example`:

```
KVANTE_LOG_LEVEL=INFO
KVANTE_LOG_DIR=/Users/oleserver/Library/Logs/Kvante
```

- [ ] **Step 3: Verify the app still starts**

Run: `cd /Users/oleserver/Kvante/backend && .venv/bin/python -c "from app.config import settings; print(settings.log_level, settings.log_dir)"`
Expected: `INFO /Users/oleserver/Library/Logs/Kvante`

- [ ] **Step 4: Commit**

```bash
git add backend/app/config.py backend/.env.example
git commit -m "feat: add log_level and log_dir settings to config"
```

---

### Task 2: Create logging_config.py with setup_logging()

**Files:**
- Create: `backend/app/logging_config.py`
- Create: `backend/tests/test_logging_config.py`

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_logging_config.py`:

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/oleserver/Kvante/backend && .venv/bin/python -m pytest tests/test_logging_config.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'app.logging_config'`

- [ ] **Step 3: Write the implementation**

Create `backend/app/logging_config.py`:

```python
import logging
import os
from logging.handlers import RotatingFileHandler

LOG_FORMAT = "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
LOG_DATEFMT = "%Y-%m-%d %H:%M:%S"
LOG_FILE = "kvante.log"
MAX_BYTES = 5 * 1024 * 1024  # 5 MB
BACKUP_COUNT = 5


def setup_logging(log_level: str, log_dir: str) -> None:
    """Configure root logger with rotating file handler and console handler."""
    os.makedirs(log_dir, exist_ok=True)
    log_path = os.path.join(log_dir, LOG_FILE)

    level = getattr(logging, log_level.upper(), logging.INFO)

    root = logging.getLogger()
    root.setLevel(level)
    root.handlers.clear()

    formatter = logging.Formatter(LOG_FORMAT, datefmt=LOG_DATEFMT)

    file_handler = RotatingFileHandler(
        log_path, maxBytes=MAX_BYTES, backupCount=BACKUP_COUNT
    )
    file_handler.setLevel(level)
    file_handler.setFormatter(formatter)
    root.addHandler(file_handler)

    console_handler = logging.StreamHandler()
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)
    root.addHandler(console_handler)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/oleserver/Kvante/backend && .venv/bin/python -m pytest tests/test_logging_config.py -v`
Expected: 3 passed

- [ ] **Step 5: Commit**

```bash
git add backend/app/logging_config.py backend/tests/test_logging_config.py
git commit -m "feat: add logging_config module with rotating file handler"
```

---

### Task 3: Wire up logging in main.py and fix test portability

**Files:**
- Modify: `backend/app/main.py:1-14`
- Modify: `backend/tests/conftest.py`

- [ ] **Step 1: Set KVANTE_LOG_DIR in conftest.py for test portability**

In `backend/tests/conftest.py`, add after the existing `os.environ` lines (line 3-4):

```python
os.environ.setdefault("KVANTE_LOG_DIR", os.path.join(tempfile.gettempdir(), "kvante-test-logs"))
```

And add `import tempfile` at the top of the file (after `import os`).

This prevents tests from writing to the user-specific absolute log path when `app.main` is imported.

- [ ] **Step 2: Replace basicConfig with setup_logging and add startup summary**

In `backend/app/main.py`, replace:

```python
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
```

with:

```python
from app.logging_config import setup_logging

setup_logging(log_level=settings.log_level, log_dir=settings.log_dir)
logger = logging.getLogger(__name__)
```

Note: the `import logging` at the top of the file is still needed for `logging.getLogger`.

- [ ] **Step 2: Add startup summary log to the lifespan function**

In `backend/app/main.py`, add after `logger.info("Database tables created")` (line 21):

```python
    logger.info(
        "Kvante starting: port=%d, ai_provider=%s, log_level=%s",
        settings.port,
        settings.ai_provider,
        settings.log_level,
    )
```

- [ ] **Step 3: Add shutdown log**

In `backend/app/main.py`, add after the `if zeroconf_instance:` cleanup block, at the end of the lifespan function just before the function ends:

```python
    logger.info("Kvante shutting down")
```

- [ ] **Step 4: Run existing tests to verify nothing breaks**

Run: `cd /Users/oleserver/Kvante/backend && .venv/bin/python -m pytest tests/ -v --timeout=30`
Expected: All existing tests pass

- [ ] **Step 5: Commit**

```bash
git add backend/app/main.py backend/tests/conftest.py
git commit -m "feat: replace basicConfig with setup_logging, add startup/shutdown logs"
```

---

### Task 4: Add timing and debug logging to ai_client.py

**Files:**
- Modify: `backend/app/services/ai_client.py`

- [ ] **Step 1: Add timing to ClaudeAIClient.send_text**

In `backend/app/services/ai_client.py`, add `import time` at the top. Then wrap the API call in `ClaudeAIClient.send_text` (lines 34-41) with timing:

```python
    def send_text(self, system_prompt: str, user_message: str) -> str:
        logger.debug("Claude send_text prompt: %s", system_prompt[:200])
        start = time.time()
        response = self._client.messages.create(
            model=self._model,
            max_tokens=4096,
            system=system_prompt,
            messages=[{"role": "user", "content": user_message}],
        )
        elapsed = time.time() - start
        self._log_usage(response.usage, elapsed)
        return response.content[0].text
```

- [ ] **Step 2: Add timing to ClaudeAIClient.send_vision**

Same pattern for `send_vision` (lines 43-73):

```python
    def send_vision(
        self,
        system_prompt: str,
        image_bytes: bytes,
        user_message: str,
        media_type: str = "image/jpeg",
    ) -> str:
        logger.debug("Claude send_vision prompt: %s", system_prompt[:200])
        image_b64 = base64.b64encode(image_bytes).decode("utf-8")
        start = time.time()
        response = self._client.messages.create(
            model=self._model,
            max_tokens=4096,
            system=system_prompt,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": media_type,
                                "data": image_b64,
                            },
                        },
                        {"type": "text", "text": user_message},
                    ],
                }
            ],
        )
        elapsed = time.time() - start
        self._log_usage(response.usage, elapsed)
        return response.content[0].text
```

- [ ] **Step 3: Update _log_usage to include elapsed time**

Replace `_log_usage` (lines 75-80):

```python
    def _log_usage(self, usage, elapsed: float) -> None:
        logger.info(
            "Claude API: %.1fs, input_tokens=%d, output_tokens=%d",
            elapsed,
            usage.input_tokens,
            usage.output_tokens,
        )
```

- [ ] **Step 4: Add timing to GeminiAIClient.send_text**

Replace `GeminiAIClient.send_text` (lines 90-101):

```python
    def send_text(self, system_prompt: str, user_message: str) -> str:
        from google.genai import types

        logger.debug("Gemini send_text prompt: %s", system_prompt[:200])
        start = time.time()
        response = self._client.models.generate_content(
            model=self._model,
            contents=user_message,
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
            ),
        )
        elapsed = time.time() - start
        logger.info("Gemini API: %.1fs, usage=%s", elapsed, response.usage_metadata)
        return response.text
```

- [ ] **Step 5: Add timing to GeminiAIClient.send_vision**

Replace `GeminiAIClient.send_vision` (lines 103-121):

```python
    def send_vision(
        self,
        system_prompt: str,
        image_bytes: bytes,
        user_message: str,
        media_type: str = "image/jpeg",
    ) -> str:
        from google.genai import types

        logger.debug("Gemini send_vision prompt: %s", system_prompt[:200])
        image_part = types.Part.from_bytes(data=image_bytes, mime_type=media_type)
        start = time.time()
        response = self._client.models.generate_content(
            model=self._model,
            contents=[image_part, user_message],
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
            ),
        )
        elapsed = time.time() - start
        logger.info("Gemini API: %.1fs, usage=%s", elapsed, response.usage_metadata)
        return response.text
```

- [ ] **Step 6: Run existing tests**

Run: `cd /Users/oleserver/Kvante/backend && .venv/bin/python -m pytest tests/test_claude_client.py -v`
Expected: All pass

- [ ] **Step 7: Commit**

```bash
git add backend/app/services/ai_client.py
git commit -m "feat: add timing and debug logging to AI client"
```

---

### Task 5: Add timing to service modules

**Files:**
- Modify: `backend/app/services/page_parser.py`
- Modify: `backend/app/services/work_analyzer.py`
- Modify: `backend/app/services/example_generator.py`
- Modify: `backend/app/services/feedback_generator.py`

All four services follow the same pattern: add `import time` and wrap the AI call with timing. The services already have `logger` instances.

- [ ] **Step 1: Add timing to page_parser.py**

In `backend/app/services/page_parser.py`, add `import time` at the top. Replace the `parse_page` method body:

```python
    def parse_page(self, image_bytes: bytes) -> dict:
        """Parse a textbook page photo into a list of assignments."""
        logger.info("Parsing textbook page (%d bytes)", len(image_bytes))
        start = time.time()
        preprocessed = preprocess_textbook_page(image_bytes)
        raw_response = self.client.send_vision(
            self._system_prompt,
            preprocessed,
            "Please identify all assignments on this textbook page and return structured JSON.",
        )
        elapsed = time.time() - start
        # Strip markdown code fences if Claude wraps the response
        cleaned = raw_response.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)
        logger.info(
            "Parsed %d assignments from page in %.1fs",
            len(parsed.get("assignments", [])),
            elapsed,
        )
        return parsed
```

- [ ] **Step 2: Add timing to work_analyzer.py**

In `backend/app/services/work_analyzer.py`, add `import time` at the top. Add timing around the `analyze_work` method. Add `logger.info` at start:

```python
    def analyze_work(
        self,
        image_bytes: bytes,
        assignment_text: str,
        assignment_type: str,
        assignment_topic: str,
    ) -> dict:
        """Analyze a photo of handwritten student work.

        Returns structured analysis. Never includes the correct answer.
        """
        logger.info("Analyzing work for '%s' (%d bytes)", assignment_text, len(image_bytes))
        start = time.time()
        preprocessed = preprocess_handwritten_work(image_bytes)
        user_message = (
            f"Assignment: {assignment_text}\n"
            f"Type: {assignment_type}\n"
            f"Topic: {assignment_topic}\n\n"
            f"Please analyze the student's handwritten work in the photo. Return JSON."
        )
        raw = self.client.send_vision(self._system_prompt, preprocessed, user_message)

        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)

        # Safety: ensure correct_answer is NEVER in the response
        parsed.pop("correct_answer", None)
        elapsed = time.time() - start

        logger.info(
            "Analyzed work for '%s' in %.1fs: confidence=%.2f, methodology_sound=%s",
            assignment_text,
            elapsed,
            parsed.get("confidence", 0),
            parsed.get("methodology_sound"),
        )
        return parsed
```

- [ ] **Step 3: Add timing to example_generator.py**

In `backend/app/services/example_generator.py`, add `import time` at the top. Add timing:

```python
    def generate_example(
        self,
        assignment_type: str,
        assignment_topic: str,
        assignment_text: str,
        language: str = "da",
    ) -> dict:
        """Generate a worked example of a similar but different problem.

        Cardinal rule: The example must NEVER use the same numbers as the real assignment.
        """
        logger.info("Generating example for %s: '%s'", assignment_type, assignment_text)
        start = time.time()
        user_message = (
            f"Assignment type: {assignment_type}\n"
            f"Assignment topic: {assignment_topic}\n"
            f"Actual assignment (use DIFFERENT numbers): {assignment_text}\n"
            f"Student's language: {language}\n\n"
            f"Create a worked example with different numbers. Return JSON."
        )
        raw = self.client.send_text(self._system_prompt, user_message)

        cleaned = raw.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("\n", 1)[1]
        if cleaned.endswith("```"):
            cleaned = cleaned.rsplit("```", 1)[0]
        cleaned = cleaned.strip()

        parsed = json.loads(cleaned)
        elapsed = time.time() - start
        logger.info(
            "Generated example for %s in %.1fs: %s",
            assignment_type,
            elapsed,
            parsed.get("example_problem"),
        )
        return parsed
```

- [ ] **Step 4: Add timing to feedback_generator.py**

In `backend/app/services/feedback_generator.py`, add `import time` at the top. Add timing to `generate_feedback` and `generate_followup`:

In `generate_feedback`, add before the `user_message` line:
```python
        logger.info("Generating feedback for '%s' (lang=%s)", assignment_text, language)
        start = time.time()
```

And after `parsed = self._parse_json(raw)`, before attaching structured prompts:
```python
        elapsed = time.time() - start
        logger.info("Generated feedback in %.1fs, tone=%s", elapsed, parsed.get("tone"))
```

In `generate_followup`, add before the `user_message` line:
```python
        logger.info("Generating followup action='%s' for '%s'", action, assignment_text)
        start = time.time()
```

And after `parsed = self._parse_json(raw)`, before attaching structured prompts:
```python
        elapsed = time.time() - start
        logger.info("Generated followup '%s' in %.1fs", action, elapsed)
```

- [ ] **Step 5: Run all tests**

Run: `cd /Users/oleserver/Kvante/backend && .venv/bin/python -m pytest tests/ -v --timeout=30`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/page_parser.py backend/app/services/work_analyzer.py backend/app/services/example_generator.py backend/app/services/feedback_generator.py
git commit -m "feat: add timing and operation logging to all service modules"
```

---

### Task 6: Add logging to image_preprocessor.py and routers

**Files:**
- Modify: `backend/app/services/image_preprocessor.py`
- Modify: `backend/app/routers/health.py`
- Modify: `backend/app/routers/assignments.py`
- Modify: `backend/app/routers/feedback.py`

- [ ] **Step 1: Add logger to image_preprocessor.py**

In `backend/app/services/image_preprocessor.py`, add after the existing imports:

```python
import logging

logger = logging.getLogger(__name__)
```

Add debug logging to `preprocess_textbook_page` (after `img = Image.open(...)`):
```python
    logger.debug("Textbook page: original size=%s, %d bytes", img.size, len(image_bytes))
```

Add debug logging to `preprocess_handwritten_work` (after `img = Image.open(...)`):
```python
    logger.debug("Handwritten work: original size=%s, %d bytes", img.size, len(image_bytes))
```

- [ ] **Step 2: Add logger to health.py**

In `backend/app/routers/health.py`, add after the existing imports:

```python
import logging

logger = logging.getLogger(__name__)
```

- [ ] **Step 3: Add logger to assignments.py**

In `backend/app/routers/assignments.py`, add after the existing imports:

```python
import logging

logger = logging.getLogger(__name__)
```

Add logging to `generate_example` endpoint, after looking up the assignment:
```python
    logger.info("Generating example for assignment %s in session %s", assignment_id, session_id)
```

Add logging to `explain_task` endpoint, after looking up the assignment:
```python
    logger.info("Explaining task for assignment %s in session %s", assignment_id, session_id)
```

- [ ] **Step 4: Add logger to feedback.py**

In `backend/app/routers/feedback.py`, add after the existing imports:

```python
import logging

logger = logging.getLogger(__name__)
```

Add logging to `generate_feedback` endpoint, after the `if not submission.analysis:` check:
```python
    logger.info("Generating feedback for submission %s", request.submission_id)
```

Add logging to `followup` endpoint, after validating the action:
```python
    logger.info("Followup action='%s' for submission %s", request.action, submission_id)
```

- [ ] **Step 5: Run all tests**

Run: `cd /Users/oleserver/Kvante/backend && .venv/bin/python -m pytest tests/ -v --timeout=30`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/image_preprocessor.py backend/app/routers/health.py backend/app/routers/assignments.py backend/app/routers/feedback.py
git commit -m "feat: add loggers to image_preprocessor and routers"
```

---

### Task 7: Create the launchd plist

**Files:**
- Create: `backend/com.kvante.backend.plist`

- [ ] **Step 1: Create the plist file**

Create `backend/com.kvante.backend.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.kvante.backend</string>

    <key>ProgramArguments</key>
    <array>
        <string>/Users/oleserver/Kvante/backend/.venv/bin/python</string>
        <string>-m</string>
        <string>uvicorn</string>
        <string>app.main:app</string>
        <string>--host</string>
        <string>0.0.0.0</string>
        <string>--port</string>
        <string>8000</string>
    </array>

    <key>WorkingDirectory</key>
    <string>/Users/oleserver/Kvante/backend</string>

    <key>UserName</key>
    <string>oleserver</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>ThrottleInterval</key>
    <integer>10</integer>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PYTHONUNBUFFERED</key>
        <string>1</string>
    </dict>

    <key>StandardOutPath</key>
    <string>/Users/oleserver/Library/Logs/Kvante/kvante-launchd.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/oleserver/Library/Logs/Kvante/kvante-launchd.log</string>
</dict>
</plist>
```

- [ ] **Step 2: Validate the plist**

Run: `plutil -lint /Users/oleserver/Kvante/backend/com.kvante.backend.plist`
Expected: `com.kvante.backend.plist: OK`

- [ ] **Step 3: Commit**

```bash
git add backend/com.kvante.backend.plist
git commit -m "feat: add launchd system daemon plist for autostart"
```

---

### Task 8: Install and test the launchd daemon

This task requires `sudo` and makes system changes. It is NOT automated — run these commands manually.

- [ ] **Step 1: Create the log directory**

```bash
mkdir -p /Users/oleserver/Library/Logs/Kvante
```

- [ ] **Step 2: Install the plist**

```bash
sudo cp /Users/oleserver/Kvante/backend/com.kvante.backend.plist /Library/LaunchDaemons/
sudo launchctl bootstrap system/ /Library/LaunchDaemons/com.kvante.backend.plist
```

- [ ] **Step 3: Verify it's running**

```bash
sudo launchctl print system/com.kvante.backend
lsof -i :8000
```

Expected: the service is listed as running and something is listening on port 8000.

- [ ] **Step 4: Verify logging works**

```bash
tail -20 /Users/oleserver/Library/Logs/Kvante/kvante.log
```

Expected: you see the startup summary log line with port, AI provider, and log level.

- [ ] **Step 5: Test auto-restart**

```bash
# Find and kill the uvicorn process
kill $(lsof -t -i :8000)
# Wait 10 seconds (ThrottleInterval)
sleep 12
lsof -i :8000
```

Expected: a new process is listening on port 8000 — launchd restarted it.

- [ ] **Step 6: Verify health endpoint**

```bash
curl http://localhost:8000/health
```

Expected: `{"status":"ok","version":"0.1.0"}`
