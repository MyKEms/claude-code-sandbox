#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# update.sh – Update an existing project with latest template files
# ─────────────────────────────────────────────────────────────────────────────
# Copies infrastructure files from the template to a project folder.
# Preserves project-specific files (.env, custom domains, workspace/).
#
# Usage:
#   ./update.sh ~/my-project-agent
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

B="\033[1m"
C="\033[36m"
G="\033[32m"
Y="\033[33m"
R="\033[31m"
D="\033[2m"
N="\033[0m"

TEMPLATE_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Resolve target ──────────────────────────────────────────────────────
TARGET_DIR="${1:-}"
if [ -z "$TARGET_DIR" ]; then
  echo ""
  echo -e "${B}${C}  Claude Code Sandbox — Update Project${N}"
  echo ""
  read -rp "  Project folder path: " TARGET_DIR
fi

if [ -z "$TARGET_DIR" ]; then
  echo -e "  ${R}No path provided. Aborting.${N}"
  exit 1
fi

# Expand ~ and make absolute
if [[ "$TARGET_DIR" == ~* ]]; then
  TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
fi
case "$TARGET_DIR" in
  /*) ;;
  *)  TARGET_DIR="$(pwd)/$TARGET_DIR" ;;
esac

# Verify it's a project
if [ ! -f "$TARGET_DIR/.env" ]; then
  echo -e "${R}  ERROR: $TARGET_DIR doesn't look like a project (no .env found)${N}"
  exit 1
fi

echo ""
echo -e "${B}${C}  Claude Code Sandbox — Update Project${N}"
echo -e "${D}  Template: $TEMPLATE_DIR${N}"
echo -e "${D}  Project:  $TARGET_DIR${N}"
echo ""

# ─── Show what will change ────────────────────────────────────────────────
CHANGES=0
for f in \
  .devcontainer/Dockerfile \
  .devcontainer/devcontainer.json \
  docker-compose.yml \
  proxy/squid.conf \
  scripts/setup-container.sh \
  scripts/welcome.sh \
  scripts/watchdog.sh \
  scripts/monitor.sh \
  scripts/proxy-ctl.sh \
  scripts/wipe.sh \
  scripts/preflight.sh \
  setup.sh \
  update.sh \
  .gitattributes \
  .gitignore \
  CLAUDE.md \
  README.md \
; do
  if [ -f "$TEMPLATE_DIR/$f" ]; then
    if [ ! -f "$TARGET_DIR/$f" ] || ! diff -q "$TEMPLATE_DIR/$f" "$TARGET_DIR/$f" &>/dev/null; then
      if [ "$CHANGES" -eq 0 ]; then
        echo -e "${B}  Files to update:${N}"
      fi
      if [ ! -f "$TARGET_DIR/$f" ]; then
        echo -e "    ${G}+ $f${N} (new)"
      else
        echo -e "    ${Y}~ $f${N}"
      fi
      CHANGES=$((CHANGES + 1))
    fi
  fi
done

if [ "$CHANGES" -eq 0 ]; then
  echo -e "  ${G}Project is already up to date.${N}"
  exit 0
fi

echo ""
echo -e "${B}  Not touched (project-specific):${N}"
echo -e "    ${D}.env${N}"
echo -e "    ${D}proxy/allowed-domains.txt${N}"
echo -e "    ${D}workspace/${N}"
echo ""

read -rp "  Apply updates? [Y/n]: " CONFIRM
if [ "${CONFIRM:-Y}" = "n" ]; then
  echo "  Cancelled."
  exit 0
fi

echo ""

# ─── Copy files ──────────────────────────────────────────────────────────
for f in \
  .devcontainer/Dockerfile \
  .devcontainer/devcontainer.json \
  docker-compose.yml \
  proxy/squid.conf \
  scripts/setup-container.sh \
  scripts/welcome.sh \
  scripts/watchdog.sh \
  scripts/monitor.sh \
  scripts/proxy-ctl.sh \
  scripts/wipe.sh \
  scripts/preflight.sh \
  setup.sh \
  update.sh \
  .gitattributes \
  .gitignore \
  CLAUDE.md \
  README.md \
; do
  if [ -f "$TEMPLATE_DIR/$f" ]; then
    mkdir -p "$TARGET_DIR/$(dirname "$f")"
    cp "$TEMPLATE_DIR/$f" "$TARGET_DIR/$f"
  fi
done

chmod +x "$TARGET_DIR/setup.sh" "$TARGET_DIR/update.sh" "$TARGET_DIR"/scripts/*.sh 2>/dev/null || true

# Restore project name in devcontainer.json (it gets overwritten by template default)
PROJ_NAME=$(grep '^PROJECT_NAME=' "$TARGET_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'")
if [ -n "$PROJ_NAME" ]; then
  sed -i.bak "s/\"name\": \".*\"/\"name\": \"${PROJ_NAME}\"/" "$TARGET_DIR/.devcontainer/devcontainer.json" && rm -f "$TARGET_DIR/.devcontainer/devcontainer.json.bak"
fi

echo -e "  ${G}$CHANGES file(s) updated.${N}"

# ─── Sync proxy allowlist files (marker-based merge) ────────────────────
# Each proxy allowlist file has a marker line (e.g. "# ADD YOUR ... BELOW").
# Template base (above marker) is replaced; user entries (below marker)
# are preserved. If a file doesn't exist in the project yet, copy it.
_sync_allowlist() {
  local filename="$1" marker="$2"
  local template_file="$TEMPLATE_DIR/proxy/$filename"
  local project_file="$TARGET_DIR/proxy/$filename"

  if [ ! -f "$template_file" ]; then return; fi

  if [ ! -f "$project_file" ]; then
    # First update after this feature was added — copy template as-is
    cp "$template_file" "$project_file"
    echo -e "  ${G}+ proxy/$filename${N} (new)"
    return
  fi

  local template_base project_base user_custom
  template_base=$(sed -n "1,/$marker/p" "$template_file")
  project_base=$(sed -n "1,/$marker/p" "$project_file")
  user_custom=$(sed -n "/$marker/,\$p" "$project_file" | tail -n +1)

  if ! diff -q <(echo "$project_base") <(echo "$template_base") &>/dev/null; then
    echo -e "  ${Y}Base entries updated in $filename${N}"
    echo -e "  ${D}Your custom entries (below '$marker') are preserved.${N}"
    echo "$template_base" > "$project_file"
    echo "$user_custom" >> "$project_file"
    # Remove the duplicate marker line
    awk "!seen[\$0]++ || \$0 !~ /$marker/" "$project_file" > "$project_file.tmp" \
      && mv "$project_file.tmp" "$project_file"
  fi
}

_sync_allowlist "allowed-domains.txt"    "# ADD YOUR DOMAINS BELOW"   "domains"
_sync_allowlist "trusted-ssh-hosts.txt"  "# ADD YOUR SSH HOSTS BELOW" "SSH hosts"
_sync_allowlist "allowed-networks.txt"   "# ADD YOUR NETWORKS BELOW"  "networks"

# ─── Check .env for missing variables ────────────────────────────────────
echo ""
MISSING_VARS=""
for VAR in PROJECT_NAME PLATFORM; do
  if ! grep -q "^${VAR}=" "$TARGET_DIR/.env" 2>/dev/null; then
    MISSING_VARS="${MISSING_VARS}  ${VAR}\n"
  fi
done

if [ -n "$MISSING_VARS" ]; then
  echo -e "  ${Y}Your .env may need new variables. Run ./setup.sh to reconfigure,${N}"
  echo -e "  ${Y}or add them manually. Missing:${N}"
  echo -e "$MISSING_VARS"
fi

# ─── Done ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${B}  Rebuild to apply:${N}"
echo "    VS Code: Cmd+Shift+P → 'Dev Containers: Rebuild Container'"
echo "    CLI:     cd $TARGET_DIR && docker compose build --no-cache && docker compose up -d"
echo ""
