#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/projects_lib.sh
source "${SCRIPT_DIR}/scripts/projects_lib.sh"

MODE="${1:-all}"
shift || true
STOP_DOCKER="${STOP_DOCKER:-0}"

if [ "$MODE" = "help" ] || [ "$MODE" = "-h" ] || [ "$MODE" = "--help" ]; then
  cat <<'EOF'
Usage: bash stop_all.sh [all|light] [project...]

Modes:
  all    Stop all managed projects + hub (default)
  light  Stop hub + offer/cPlusBook/encoding/rust-compile only

Environment:
  STOP_DOCKER=1   Also stop wisdom/WestChina Docker middleware

Examples:
  bash stop_all.sh
  bash stop_all.sh light
  bash stop_all.sh offer encoding
  STOP_DOCKER=1 bash stop_all.sh wisdom westchina
EOF
  exit 0
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "light" ]; then
  SELECT=("$@")
else
  SELECT=("$MODE" "$@")
  MODE="all"
fi

stop_hub() {
  log "=== stop ProjectAccess (18200) ==="
  stop_pid hub
  kill_port 18200
  sleep 0.5
  kill_port_hard 18200
}

stop_offer() {
  log "=== stop offer (4000) ==="
  stop_pid offer
  kill_port 4000
}

stop_cplusbook() {
  log "=== stop cPlusBook (4001) ==="
  stop_pid cplusbook
  kill_port 4001
}

stop_encoding() {
  log "=== stop encoding_practice (3000) ==="
  stop_pid encoding
  pkill -f "${DEPLOY_ROOT}/encoding_practice/protocol_tutorial/target/debug/web" 2>/dev/null || true
  kill_port 3000
}

stop_rust_compile() {
  log "=== stop rust-compile-web (5175/8080/18080) ==="
  stop_pid rust-frontend
  stop_pid rust-backend
  pkill -f "${DEPLOY_ROOT}/rust-compile-web/frontend/node_modules/.bin/vite" 2>/dev/null || true
  pkill -f "${DEPLOY_ROOT}/rust-compile-web/backend/target/debug/rust-compile-backend" 2>/dev/null || true
  kill_port 5175
  for port in 8080 18080; do
    local pid
    for pid in $(pids_on_port "$port"); do
      if ps -p "$pid" -o args= 2>/dev/null | grep -q 'rust-compile-backend'; then
        kill "$pid" 2>/dev/null || true
      fi
    done
  done
}

stop_wisdom() {
  log "=== stop wisdom ==="
  if [ -f "${DEPLOY_ROOT}/wisdom/stop_all.sh" ]; then
    if [ "$STOP_DOCKER" = "1" ]; then
      bash "${DEPLOY_ROOT}/wisdom/stop_all.sh" docker >>"${RUN_DIR}/wisdom-stop.log" 2>&1 || true
    else
      bash "${DEPLOY_ROOT}/wisdom/stop_all.sh" app >>"${RUN_DIR}/wisdom-stop.log" 2>&1 || true
    fi
  fi
  stop_pid wisdom
  kill_port 9527
}

stop_westchina() {
  log "=== stop WestChina-Cloud ==="
  if [ -f "${DEPLOY_ROOT}/WestChina-Cloud/stop_all.sh" ]; then
    if [ "$STOP_DOCKER" = "1" ]; then
      bash "${DEPLOY_ROOT}/WestChina-Cloud/stop_all.sh" docker >>"${RUN_DIR}/westchina-stop.log" 2>&1 || true
    else
      bash "${DEPLOY_ROOT}/WestChina-Cloud/stop_all.sh" >>"${RUN_DIR}/westchina-stop.log" 2>&1 || true
    fi
  fi
  stop_pid westchina
  kill_port 5000
}

stop_fengsheng() {
  log "=== stop fengsheng (5173) ==="
  stop_pid fengsheng
  # Only kill vite under the fengsheng prototype tree (not rust-compile on 5175)
  if [ -n "${FENGSHENG_DIR:-}" ] && [ -d "${FENGSHENG_DIR}" ]; then
    pkill -f "${FENGSHENG_DIR}/node_modules/.bin/vite" 2>/dev/null || true
  fi
  kill_port 5173
}

# Stop hub first, then lightweight apps, then heavy stacks.
if should_run_project hub "$MODE" "${SELECT[@]}"; then stop_hub; fi
if should_run_project rust-compile "$MODE" "${SELECT[@]}"; then stop_rust_compile; fi
if should_run_project fengsheng "$MODE" "${SELECT[@]}"; then stop_fengsheng; fi
if should_run_project offer "$MODE" "${SELECT[@]}"; then stop_offer; fi
if should_run_project cplusbook "$MODE" "${SELECT[@]}"; then stop_cplusbook; fi
if should_run_project encoding "$MODE" "${SELECT[@]}"; then stop_encoding; fi
if should_run_project westchina "$MODE" "${SELECT[@]}"; then stop_westchina; fi
if should_run_project wisdom "$MODE" "${SELECT[@]}"; then stop_wisdom; fi

log "=== stop_all done ==="
bash "${SCRIPT_DIR}/status_all.sh"
