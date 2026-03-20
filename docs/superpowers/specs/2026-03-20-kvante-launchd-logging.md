# Kvante — launchd Autostart and Logging

**Date:** 2026-03-20
**Status:** Approved

## Overview

Add a macOS launchd system daemon to autostart the Kvante backend at boot, and add structured file-based logging with configurable verbosity for troubleshooting.

## 1. Launchd System Daemon

**Plist location:** `/Library/LaunchDaemons/com.kvante.backend.plist`

The daemon uses `ProgramArguments` (not `Program`) because launchd requires arguments as a string array — it does not accept a single command string with arguments.

The Python binary must be referenced by its full absolute path (`/Users/oleserver/Kvante/backend/.venv/bin/python`) because launchd does not run a shell and has no PATH resolution.

**Complete plist:**

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

**Environment variables and `.env`:** API keys are NOT embedded in the plist. Since `WorkingDirectory` is set to the backend directory, pydantic-settings will find and load `.env` as usual. This is simpler and avoids putting sensitive keys in a world-readable system plist (`/Library/LaunchDaemons/` files are typically `root:wheel 644`). If `.env` loading ever fails under launchd, the fix is to change `config.py` to use an absolute path: `"env_file": "/Users/oleserver/Kvante/backend/.env"`.

Add `PYTHONUNBUFFERED=1` to the plist `EnvironmentVariables` to ensure Python flushes stdout/stderr immediately — without this, log lines can appear delayed or be lost on crash.

**Why system daemon over user agent:** The Mac Mini may reboot and sit at the login screen — a system daemon starts at boot regardless of login state. A user agent (`~/Library/LaunchAgents/`) would be simpler but requires the user to be logged in.

**Install/uninstall commands:**

```bash
# Install
sudo cp com.kvante.backend.plist /Library/LaunchDaemons/
sudo launchctl bootstrap system/ /Library/LaunchDaemons/com.kvante.backend.plist

# Uninstall
sudo launchctl bootout system/com.kvante.backend
sudo rm /Library/LaunchDaemons/com.kvante.backend.plist

# Check status
sudo launchctl print system/com.kvante.backend
```

**Log directory pre-creation:** The install process must create the log directory before loading the plist, since launchd (running as root) writes `StandardOutPath`/`StandardErrorPath` before dropping privileges:

```bash
mkdir -p /Users/oleserver/Library/Logs/Kvante
```

The `logging_config.py` setup function also calls `os.makedirs(..., exist_ok=True)` as a safety net for the app's own log file.

## 2. Logging Setup

**New file:** `backend/app/logging_config.py`

**Log file:** `/Users/oleserver/Library/Logs/Kvante/kvante.log`

**Rotation:** `RotatingFileHandler` — 5MB per file, keep 5 backups (~30MB max on disk).

**Format:** `2026-03-20 14:32:01 [INFO] app.main: Database tables created`

**Outputs:**
- File handler: writes to the log file with rotation
- Console handler: writes to stdout (launchd fallback capture gets a copy)

**Levels (configurable via `KVANTE_LOG_LEVEL` env var, `KVANTE_LOG_DIR` to override log directory):**
- `INFO` (default): requests, startup/shutdown, errors, AI API call durations, Bonjour registration
- `DEBUG` (verbose): adds full AI prompt/response payloads, image preprocessing details, DB queries

**Config integration:** Add `log_level: str = "INFO"` and `log_dir: str = "/Users/oleserver/Library/Logs/Kvante"` to the `Settings` class in `config.py`. Use an absolute path as the default to avoid tilde expansion issues (`RotatingFileHandler` and `os.makedirs` do not expand `~`).

**Startup change:** Replace `logging.basicConfig()` in `main.py` with a call to the new setup function.

## 3. What Gets Logged

Logging additions across the codebase (no business logic changes):

- **`main.py`:** startup config summary (port, AI provider, log level), shutdown reason
- **`ai_client.py`:** API call duration and token usage at INFO; full prompt/response at DEBUG
- **`page_parser.py` / `work_analyzer.py` / `example_generator.py` / `feedback_generator.py`:** operation start/completion with timing at INFO; full AI payloads at DEBUG. Some of these files currently lack a `logger` instance — those are added as part of this work.
- **`image_preprocessor.py`:** preprocessing steps and image dimensions at DEBUG. Currently lacks a `logger` instance — added as part of this work.
- **Routers (`feedback.py`, `assignments.py`, `health.py`):** currently lack `logger` instances — added as part of this work. Request received / response sent with endpoint and status code at INFO.
- **Errors:** full tracebacks at ERROR level, including AI API failures and image processing failures

## 4. Files Changed

- **New:** `backend/app/logging_config.py` — logging setup function
- **New:** `com.kvante.backend.plist` — launchd plist (committed to repo, installed to `/Library/LaunchDaemons/` with sudo)
- **Modified:** `backend/app/config.py` — add `log_level` and `log_dir` settings
- **Modified:** `backend/app/main.py` — replace `basicConfig` with new logging setup, add startup summary log
- **Modified:** `backend/app/services/ai_client.py` — add timing and payload logging
- **Modified:** `backend/app/services/page_parser.py` — add operation logging
- **Modified:** `backend/app/services/work_analyzer.py` — add operation logging
- **Modified:** `backend/app/services/example_generator.py` — add operation logging
- **Modified:** `backend/app/services/feedback_generator.py` — add operation logging
- **Modified:** `backend/app/services/image_preprocessor.py` — add debug logging
- **Modified:** `backend/app/routers/*.py` — ensure consistent request/response logging
- **Modified:** `backend/.env.example` — add `KVANTE_LOG_LEVEL` and `KVANTE_LOG_DIR` entries
