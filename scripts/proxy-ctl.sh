#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# proxy-ctl.sh – Quick helper for managing the proxy allowlist
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOMAINS_FILE="$SCRIPT_DIR/proxy/allowed-domains.txt"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  list                   Show all active (non-commented) domains
  add <domain>           Add a domain to the allowlist and reload proxy
  remove <domain>        Comment out a domain and reload proxy
  test <url>             Test if a URL is reachable through the proxy
  logs                   Tail proxy access logs (Ctrl+C to stop)
  reload                 Restart the proxy to pick up config changes

Examples:
  $(basename "$0") add .pypi.org
  $(basename "$0") test https://api.anthropic.com/v1/messages
  $(basename "$0") list
EOF
}

reload_proxy() {
  echo "Reloading proxy..."
  docker compose -f "$SCRIPT_DIR/docker-compose.yml" restart proxy
  echo "Proxy reloaded"
}

case "${1:-}" in
  list)
    echo "Active allowed domains:"
    grep -v '^\s*#' "$DOMAINS_FILE" | grep -v '^\s*$' | sort
    ;;
  add)
    [[ -z "${2:-}" ]] && { echo "Error: specify a domain, e.g.: add .pypi.org"; exit 1; }
    domain="$2"
    if grep -qF "$domain" "$DOMAINS_FILE"; then
      sed -i.bak "s|^#\s*${domain}|${domain}|" "$DOMAINS_FILE" && rm -f "$DOMAINS_FILE.bak"
      echo "Uncommented: $domain"
    else
      echo "$domain" >> "$DOMAINS_FILE"
      echo "Added: $domain"
    fi
    reload_proxy
    ;;
  remove)
    [[ -z "${2:-}" ]] && { echo "Error: specify a domain"; exit 1; }
    domain="$2"
    sed -i.bak "s|^${domain}|# ${domain}|" "$DOMAINS_FILE" && rm -f "$DOMAINS_FILE.bak"
    echo "Commented out: $domain"
    reload_proxy
    ;;
  test)
    [[ -z "${2:-}" ]] && { echo "Error: specify a URL, e.g.: test https://api.anthropic.com"; exit 1; }
    url="$2"
    echo "Testing: $url (through proxy)"
    docker compose -f "$SCRIPT_DIR/docker-compose.yml" exec claude \
      curl -s -o /dev/null -w "HTTP %{http_code} (%{time_total}s)\n" \
      --proxy http://proxy:3128 "$url" || echo "Connection failed"
    ;;
  logs)
    docker compose -f "$SCRIPT_DIR/docker-compose.yml" logs -f proxy
    ;;
  reload)
    reload_proxy
    ;;
  *)
    usage
    ;;
esac
