#!/usr/bin/env bash
#
# deploy.sh — Push backend changes to Mac Mini and verify health.
#
# Usage:  ./scripts/deploy.sh
#
# Workflow:
#   1. Refuse if there are uncommitted changes (commit first)
#   2. Push current branch to origin
#   3. SSH to Mac Mini and pull
#   4. Wait briefly for uvicorn --reload to pick up changes
#   5. curl /health and report status
#
# Requires: backend launchd plist must include --reload (auto-restart on
#           file changes). See backend/com.kvante.backend.plist.

set -euo pipefail

REMOTE_USER="oleserver"
REMOTE_HOST="macmini4"
REMOTE_PATH="~/Kvante"
HEALTH_URL="http://192.168.1.60:8000/health"

# Colors for output
GREEN=$(tput setaf 2 2>/dev/null || echo "")
RED=$(tput setaf 1 2>/dev/null || echo "")
YELLOW=$(tput setaf 3 2>/dev/null || echo "")
RESET=$(tput sgr0 2>/dev/null || echo "")

info()  { echo "${YELLOW}→${RESET} $*"; }
ok()    { echo "${GREEN}✓${RESET} $*"; }
fail()  { echo "${RED}✗${RESET} $*" >&2; }

# 1. Refuse on uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    fail "Uncommitted changes in working tree. Commit first, then deploy."
    git status --short
    exit 1
fi

BRANCH=$(git branch --show-current)
info "Deploying branch '${BRANCH}' to ${REMOTE_USER}@${REMOTE_HOST}"

# 2. Push current branch
info "Pushing to origin..."
git push origin "${BRANCH}"
ok "Pushed"

# 3. Pull on Mac Mini
info "Pulling on ${REMOTE_HOST}..."
ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ${REMOTE_PATH} && git fetch origin && git checkout ${BRANCH} && git pull --ff-only origin ${BRANCH}"
ok "Pulled on remote"

# 4. Wait for uvicorn --reload to detect changes and restart
info "Waiting for backend reload..."
sleep 3

# 5. Health check
info "Checking ${HEALTH_URL}..."
if curl -sf --max-time 5 "${HEALTH_URL}" > /dev/null; then
    ok "Backend healthy — deploy complete"
else
    fail "Backend health check failed"
    info "Tail logs with: ssh ${REMOTE_USER}@${REMOTE_HOST} tail -50 ~/Library/Logs/Kvante/kvante.log"
    exit 1
fi
