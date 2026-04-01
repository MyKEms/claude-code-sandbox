#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# wipe.sh – Clean reset of the container environment
# ─────────────────────────────────────────────────────────────────────────────
# Usage:
#   ./scripts/wipe.sh              # interactive menu
#   ./scripts/wipe.sh --soft       # sessions/logs only (keep volumes)
#   ./scripts/wipe.sh --hard       # destroy containers, volumes, images
#   ./scripts/wipe.sh --nuclear    # hard + clean host ~/.claude sessions
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

B="\033[1m"
R="\033[31m"
G="\033[32m"
Y="\033[33m"
N="\033[0m"

cd "$(dirname "$0")/.."

echo -e "${B}=== Safe Agentic AI — Wipe Tool ===${N}"
echo ""

MODE="${1:-}"

# ─── Interactive mode ────────────────────────────────────────────────────────
if [ -z "$MODE" ]; then
  echo "What do you want to clean?"
  echo ""
  echo -e "  ${G}1) Soft reset${N}  – Container sessions, logs, MCP config"
  echo "                  (host sessions UNTOUCHED)"
  echo ""
  echo -e "  ${Y}2) Hard reset${N}  – Soft + containers, volumes, images"
  echo "                  (full rebuild, host sessions UNTOUCHED)"
  echo ""
  echo -e "  ${R}3) Nuclear${N}     – Hard + ALL sessions (host too!)"
  echo "                  (WARNING: affects host Claude CLI too!)"
  echo ""
  read -rp "Choice [1/2/3]: " CHOICE
  case "$CHOICE" in
    1) MODE="--soft" ;;
    2) MODE="--hard" ;;
    3) MODE="--nuclear" ;;
    *) echo "Cancelled."; exit 0 ;;
  esac
fi

echo ""

# ─── Soft reset ──────────────────────────────────────────────────────────────
if [ "$MODE" = "--soft" ]; then
  echo -e "${G}>>> Soft reset${N}"
  echo "Cleaning ONLY container sessions (host sessions untouched)..."

  CLAUDE_DIR="$HOME/.claude"

  for d in "$CLAUDE_DIR"/projects/-workspace*; do
    [ -d "$d/sessions" ] && rm -rf "$d/sessions"/* 2>/dev/null
  done
  echo "  Container project sessions:  cleared"

  rm -rf "$CLAUDE_DIR"/watchdog-logs/* 2>/dev/null
  echo "  Watchdog logs:               cleared"

  docker compose exec claude rm -f /home/vscode/.claude.json 2>/dev/null || true
  echo "  MCP config:                  cleared"

  docker compose exec claude bash -c "rm -rf /tmp/* 2>/dev/null" || true
  echo "  Container /tmp:              cleared"

  echo ""
  echo -e "  ${B}NOT touched:${N}"
  echo "  ~/.claude/sessions/          (global sessions)"
  echo "  ~/.claude/projects/-Users-*  (host project sessions)"
  echo ""
  echo -e "${G}Done.${N} Run 'bash /scripts/setup-container.sh' inside to re-setup MCP."

# ─── Hard reset ──────────────────────────────────────────────────────────────
elif [ "$MODE" = "--hard" ]; then
  echo -e "${Y}>>> Hard reset${N}"
  read -rp "Destroy containers, volumes, images (host sessions safe). Continue? [y/N]: " CONFIRM
  [ "$CONFIRM" != "y" ] && echo "Cancelled." && exit 0

  CLAUDE_DIR="$HOME/.claude"
  for d in "$CLAUDE_DIR"/projects/-workspace*; do
    [ -d "$d/sessions" ] && rm -rf "$d/sessions"/* 2>/dev/null
  done
  rm -rf "$CLAUDE_DIR"/watchdog-logs/* 2>/dev/null
  echo "  Container sessions: cleared"

  echo "Stopping containers..."
  docker compose down -v 2>/dev/null
  echo "  Containers + volumes: removed"

  echo "Removing images..."
  docker compose down --rmi local 2>/dev/null
  echo "  Images: removed (will rebuild)"

  docker builder prune -f 2>/dev/null | tail -1
  echo ""
  echo -e "  ${B}NOT touched:${N} host sessions, credentials, settings, workspace"
  echo ""
  echo -e "${Y}Done.${N} Run 'docker compose build && docker compose up -d' to rebuild."

# ─── Nuclear reset ───────────────────────────────────────────────────────────
elif [ "$MODE" = "--nuclear" ]; then
  echo -e "${R}>>> Nuclear reset${N}"
  echo -e "${R}WARNING: This will also clean host ~/.claude sessions!${N}"
  read -rp "Type 'nuke' to confirm: " CONFIRM
  [ "$CONFIRM" != "nuke" ] && echo "Cancelled." && exit 0

  docker compose down -v --rmi local 2>/dev/null
  echo "  Containers + volumes + images: destroyed"

  rm -rf ~/.claude/sessions/* 2>/dev/null
  rm -rf ~/.claude/projects/*/sessions/* 2>/dev/null
  echo "  ~/.claude/sessions: cleared"
  echo ""
  echo -e "${R}NOT removed (by design):${N}"
  echo "  ~/.claude/.credentials.json   (your OAuth login)"
  echo "  ~/.claude/settings.json       (your preferences)"
  echo "  ~/.ssh/                        (SSH keys)"
  echo "  workspace/                     (your repos)"
  echo ""
  echo -e "${R}Done.${N} Fresh start: docker compose build && docker compose up -d"
fi

echo ""
echo "─────────────────────────────────────"
echo "Cheat sheet:"
echo "  docker compose build --no-cache   # full image rebuild"
echo "  docker compose up -d              # start containers"
echo "  VS Code: 'Reopen in Container'    # attach VS Code"
echo "─────────────────────────────────────"
