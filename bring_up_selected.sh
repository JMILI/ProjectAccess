#!/usr/bin/env bash
# Bring up local + tunnels for: cplusbook encoding rust-compile WestChina hub
# Run as ubuntu2404 (not root):
#   bash /home/ubuntu2404/code_jm/deployProject/ProjectAccess/bring_up_selected.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FE_DIR="${DEPLOY_ROOT}/rust-compile-web/frontend"
PROJECTS=(cplusbook encoding rust-compile WestChina hub)

log() { printf '[bring_up] %s\n' "$*"; }

if [ "$(id -u)" -eq 0 ]; then
  log "ERROR: run as ubuntu2404, not root"
  exit 1
fi

log "=== 1) fix leftover root-owned cargo files (sudo once) ==="
sudo chown -R ubuntu2404:ubuntu2404 "${HOME}/.cargo" || true

log "=== 2) ensure rust-compile frontend deps (vite) ==="
if [ ! -x "${FE_DIR}/node_modules/.bin/vite" ]; then
  log "npm install in ${FE_DIR}"
  (cd "${FE_DIR}" && npm install)
else
  log "vite already present"
fi

log "=== 3) sealtun login check ==="
if ! sealtun status 2>/dev/null | grep -q "Logged in: yes"; then
  log "sealtun not logged in — running: sealtun login gzg"
  sealtun login gzg
fi
sealtun status 2>&1 | head -n 30 || true

log "=== 4) stop then start LOCAL + TUNNEL ==="
bash "${SCRIPT_DIR}/stop_all.sh" "${PROJECTS[@]}" || true

# Longer WestChina wait helps cold Java boots
export WESTCHINA_WAIT_SEC="${WESTCHINA_WAIT_SEC:-300}"
bash "${SCRIPT_DIR}/start_all.sh" "${PROJECTS[@]}"

log "=== 5) final status ==="
bash "${SCRIPT_DIR}/status_all.sh" || true
ss -tlnp 2>/dev/null | grep -E ':(18200|3000|4001|5000|5175|18080)\s' || true

log "done"
