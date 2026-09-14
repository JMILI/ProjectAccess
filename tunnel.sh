#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/projects_lib.sh
source "${SCRIPT_DIR}/scripts/projects_lib.sh"
cd "$SCRIPT_DIR"

if ! resolve_sealtun_cmd >/dev/null; then
  echo "[error] sealtun 未安装（npm i -g sealtun 或确保 PATH 含 sealtun）"
  exit 1
fi

SEALTUN_CMD="$(resolve_sealtun_cmd)"
sealtun_run() {
  # shellcheck disable=SC2086
  $SEALTUN_CMD "$@"
}

ACTION="${1:-status}"
shift || true

case "$ACTION" in
  apply)
    # Usage: bash tunnel.sh apply [all|light|project...]
    MODE="all"
    SELECT=()
    if [ "${1:-}" = "all" ] || [ "${1:-}" = "light" ]; then
      MODE="$1"
      shift || true
      SELECT=("$@")
    elif [ "$#" -gt 0 ]; then
      SELECT=("$@")
    else
      # No filter: treat every project as selected; ensure_selected_tunnels
      # still skips ports that are not listening.
      SELECT=("${ALL_PROJECTS[@]}")
    fi
    ensure_selected_tunnels "$MODE" "${SELECT[@]}"
    sealtun_run list 2>/dev/null || true
    ;;
  status)
    sealtun_run list
    ;;
  delete | stop)
    if [ "$#" -eq 0 ]; then
      ID="$(sealtun_run list 2>/dev/null | awk '/project-access|project-hub-rust/ {print $1; exit}')"
      if [ -n "$ID" ]; then
        sealtun_run stop "$ID"
      else
        echo "no project-access tunnel found"
      fi
      exit 0
    fi
    for item in "$@"; do
      spec="$(tunnel_spec_for_project "$item" || true)"
      [ -z "$spec" ] && continue
      name="${spec%%:*}"
      if sealtun_run list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$name"; then
        log "stop tunnel ${name}"
        sealtun_run stop "$name" || true
      fi
    done
    ;;
  *)
    cat <<'EOF'
Usage: bash tunnel.sh [apply|status|stop] [projects...]

  apply              Start tunnels for every local port currently listening
  apply light        Start tunnels for light projects (if ports up)
  apply hub encoding Start tunnels only for listed projects
  status             sealtun list
  stop [projects...] Stop named tunnels

Examples:
  bash tunnel.sh apply
  bash tunnel.sh apply cplusbook encoding rust-compile WestChina hub
EOF
    exit 1
    ;;
esac
