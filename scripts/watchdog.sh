#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# watchdog.sh – Run Claude Code with auto-restart on crash
# ─────────────────────────────────────────────────────────────────────────────
# Usage:
#   /scripts/watchdog.sh                        # interactive, restarts on crash
#   /scripts/watchdog.sh -p "fix all tests"     # headless print mode
#   /scripts/watchdog.sh --resume <session-id>  # resume a previous session
#
# Env overrides:
#   MAX_RESTARTS=50   – max restart attempts (default 50)
#   COOLDOWN=10       – seconds between restarts (default 10)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

LOG_DIR="/home/vscode/.claude/watchdog-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/watchdog-$(date -u '+%Y%m%d-%H%M%S').log"

MAX_RESTARTS="${MAX_RESTARTS:-50}"
COOLDOWN="${COOLDOWN:-10}"
RESTART_COUNT=0

log() {
  local msg
  msg="[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}

cleanup() {
  log "Watchdog received signal, shutting down gracefully..."
  if [ -n "${CLAUDE_PID:-}" ] && kill -0 "$CLAUDE_PID" 2>/dev/null; then
    kill -TERM "$CLAUDE_PID" 2>/dev/null
    wait "$CLAUDE_PID" 2>/dev/null
  fi
  log "Watchdog stopped (total restarts: $RESTART_COUNT)"
  exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP

log "=== Watchdog started ==="
log "Max restarts: $MAX_RESTARTS | Cooldown: ${COOLDOWN}s"
log "Claude args: $*"
log "Log file: $LOG_FILE"

while [ "$RESTART_COUNT" -lt "$MAX_RESTARTS" ]; do
  RESTART_COUNT=$((RESTART_COUNT + 1))
  log "--- Starting Claude Code (attempt $RESTART_COUNT/$MAX_RESTARTS) ---"

  EXIT_CODE=0
  claude --dangerously-skip-permissions "$@" &
  CLAUDE_PID=$!
  wait "$CLAUDE_PID" || EXIT_CODE=$?
  unset CLAUDE_PID

  log "Claude exited with code $EXIT_CODE"

  # Clean exit (0) or user interrupt (130 = SIGINT) → don't restart
  if [ "$EXIT_CODE" -eq 0 ] || [ "$EXIT_CODE" -eq 130 ]; then
    log "Clean exit, watchdog stopping"
    break
  fi

  if [ "$RESTART_COUNT" -ge "$MAX_RESTARTS" ]; then
    log "Max restarts reached ($MAX_RESTARTS), giving up"
    break
  fi

  log "Restarting in ${COOLDOWN}s... (Ctrl+C to abort)"
  sleep "$COOLDOWN"
done

log "=== Watchdog finished (restarts: $RESTART_COUNT) ==="
echo "Full log: $LOG_FILE"
