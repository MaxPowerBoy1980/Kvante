# Kvante — launchd Autostart and Logging

**Date:** 2026-03-20
**Status:** Approved

## Overview

Add a macOS launchd system daemon to autostart the Kvante backend at boot, and add structured file-based logging with configurable verbosity for troubleshooting.

## 1. Launchd System Daemon

**Plist location:** `/Library/LaunchDaemons/com.kvante.backend.plist`

**Configuration:**
- **Program:** `/Users/oleserver/Kvante/backend/.venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000`
- **WorkingDirectory:** `/Users/oleserver/Kvante/backend`
- **UserName:** `oleserver`
- **KeepAlive:** `true` — launchd restarts the process on any exit
- **ThrottleInterval:** `10` — seconds between restart attempts to prevent tight loops
- **StandardOutPath / StandardErrorPath:** `/Users/oleserver/Library/Logs/Kvante/kvante-launchd.log` — launchd's own capture as a fallback
- **EnvironmentVariables:** key values from `.env` (API keys, provider config) embedded in the plist

**Install/uninstall:** requires `sudo` since it's a system daemon.

## 2. Logging Setup

**New file:** `backend/app/logging_config.py`

**Log file:** `~/Library/Logs/Kvante/kvante.log`

**Rotation:** `RotatingFileHandler` — 5MB per file, keep 5 backups (~30MB max on disk).

**Format:** `2026-03-20 14:32:01 [INFO] app.main: Database tables created`

**Outputs:**
- File handler: writes to the log file with rotation
- Console handler: writes to stdout (launchd fallback capture gets a copy)

**Levels (configurable via `KVANTE_LOG_LEVEL` env var):**
- `INFO` (default): requests, startup/shutdown, errors, AI API call durations, Bonjour registration
- `DEBUG` (verbose): adds full AI prompt/response payloads, image preprocessing details, DB queries

**Config integration:** add `log_level: str = "INFO"` and `log_dir: str = "~/Library/Logs/Kvante"` to the `Settings` class in `config.py`. The logging module creates the log directory if it doesn't exist.

**Startup change:** replace `logging.basicConfig()` in `main.py` with a call to the new setup function.

## 3. What Gets Logged

Logging additions across the codebase (no business logic changes):

- **`main.py`:** startup config summary (port, AI provider, log level), shutdown reason
- **`ai_client.py`:** API call duration and token usage at INFO; full prompt/response at DEBUG
- **`page_parser.py` / `work_analyzer.py` / `example_generator.py` / `feedback_generator.py`:** operation start/completion with timing at INFO; full AI payloads at DEBUG
- **`image_preprocessor.py`:** preprocessing steps and image dimensions at DEBUG
- **Routers:** request received / response sent with endpoint and status code at INFO
- **Errors:** full tracebacks at ERROR level, including AI API failures and image processing failures

## 4. Files Changed

- **New:** `backend/app/logging_config.py` — logging setup function
- **New:** `/Library/LaunchDaemons/com.kvante.backend.plist` — launchd plist (installed with sudo)
- **Modified:** `backend/app/config.py` — add `log_level` and `log_dir` settings
- **Modified:** `backend/app/main.py` — replace `basicConfig` with new logging setup, add startup summary log
- **Modified:** `backend/app/services/ai_client.py` — add timing and payload logging
- **Modified:** `backend/app/services/page_parser.py` — add operation logging
- **Modified:** `backend/app/services/work_analyzer.py` — add operation logging
- **Modified:** `backend/app/services/example_generator.py` — add operation logging
- **Modified:** `backend/app/services/feedback_generator.py` — add operation logging
- **Modified:** `backend/app/services/image_preprocessor.py` — add debug logging
- **Modified:** `backend/app/routers/*.py` — ensure consistent request/response logging
