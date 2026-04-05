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
  echo "Cleaning container sessions and temp files..."

  docker compose exec claude bash -c "rm -rf /home/vscode/.claude/sessions/* /home/vscode/.claude/projects/*/sessions/* 2>/dev/null" || true
  echo "  Claude sessions:  cleared"

  docker compose exec claude rm -f /home/vscode/.claude.json 2>/dev/null || true
  echo "  MCP config:       cleared"

  docker compose exec claude bash -c "rm -rf /tmp/* 2>/dev/null" || true
  echo "  Container /tmp:   cleared"

  echo ""
  echo -e "  ${B}NOT touched:${N}"
  echo "  Claude credentials (docker volume)"
  echo "  Workspace files"
  echo ""
  echo -e "${G}Done.${N} Run 'bash /scripts/setup-container.sh' inside to re-setup MCP."

# ─── Hard reset ──────────────────────────────────────────────────────────────
elif [ "$MODE" = "--hard" ]; then
  echo -e "${Y}>>> Hard reset${N}"
  echo "Destroys containers, volumes (including Claude credentials), and images."
  read -rp "Continue? [y/N]: " CONFIRM
  [ "$CONFIRM" != "y" ] && echo "Cancelled." && exit 0

  echo "Stopping containers..."
  docker compose down -v 2>/dev/null
  echo "  Containers + volumes: removed (Claude credentials lost — will need to re-login)"

  echo "Removing images..."
  docker compose down --rmi local 2>/dev/null
  echo "  Images: removed (will rebuild)"

  docker builder prune -f 2>/dev/null | tail -1
  echo ""
  echo -e "  ${B}NOT touched:${N} workspace files, host SSH keys"
  echo ""
  echo -e "${Y}Done.${N} Run 'docker compose build && docker compose up -d' to rebuild."

# ─── Nuclear reset ───────────────────────────────────────────────────────────
elif [ "$MODE" = "--nuclear" ]; then
  echo -e "${R}>>> Nuclear reset${N}"
  echo "Destroys everything: containers, volumes, images, and workspace files."
  read -rp "Type 'nuke' to confirm: " CONFIRM
  [ "$CONFIRM" != "nuke" ] && echo "Cancelled." && exit 0

  docker compose down -v --rmi local 2>/dev/null
  echo "  Containers + volumes + images: destroyed"
  echo ""
  echo -e "${R}NOT removed (by design):${N}"
  echo "  .env                           (project config)"
  echo "  proxy/allowed-domains.txt      (domain allowlist)"
  echo "  ~/.ssh/                        (host SSH keys)"
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
