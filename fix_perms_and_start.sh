#!/usr/bin/env bash
# One-shot: fix root-owned dirs + corrupted Cargo.lock, then start local services.
# Run as ubuntu2404 (not root) so sudo prompts once:
#   bash /home/ubuntu2404/code_jm/deployProject/ProjectAccess/fix_perms_and_start.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
USER_NAME="ubuntu2404"
ENCODING_DIR="${DEPLOY_ROOT}/encoding_practice"
BACKUP_LOCK="${DEPLOY_ROOT}/encoding_practice.pre-existing-20261031/protocol_tutorial/Cargo.lock"
LOCK_PATH="${ENCODING_DIR}/protocol_tutorial/Cargo.lock"
PROTO_DIR="${ENCODING_DIR}/protocol_tutorial"

log() { printf '[fix_perms_and_start] %s\n' "$*"; }

if [ "$(id -u)" -eq 0 ]; then
  log "ERROR: do not run this script as root; run as ${USER_NAME} so sudo prompts once."
  exit 1
fi

log "=== 1) chown project dirs + cargo registry (needs sudo) ==="
# set -e: chown failure aborts the script (must not continue with root-owned trees)
sudo chown -R "${USER_NAME}:${USER_NAME}" \
  "${DEPLOY_ROOT}/encoding_practice" \
  "${DEPLOY_ROOT}/cPlusBook" \
  "${DEPLOY_ROOT}/miniProgram" \
  "${HOME}/.cargo/registry"
log "chown OK"

log "=== 2) restore protocol_tutorial/Cargo.lock from git HEAD ==="
if ! git config --global --get-all safe.directory 2>/dev/null | grep -qxF "${ENCODING_DIR}"; then
  git config --global --add safe.directory "${ENCODING_DIR}" || true
fi

# HEAD blob is known-good (~650 lines). Always restore from git after chown.
checkout_ok=0
if git -C "${ENCODING_DIR}" checkout -- protocol_tutorial/Cargo.lock; then
  log "git checkout restored protocol_tutorial/Cargo.lock"
  checkout_ok=1
else
  log "git checkout failed; trying backup copy"
  if [ -f "${BACKUP_LOCK}" ]; then
    cp -f "${BACKUP_LOCK}" "${LOCK_PATH}"
    log "copied Cargo.lock from encoding_practice.pre-existing-20261031"
  else
    log "WARNING: backup lockfile missing at ${BACKUP_LOCK}"
  fi
fi

if [ -f "${LOCK_PATH}" ] && grep -qF 'Showing lines' "${LOCK_PATH}"; then
  log "Cargo.lock still contains truncation artifact 'Showing lines'; regenerating"
  rm -f "${LOCK_PATH}"
  (
    cd "${PROTO_DIR}"
    cargo generate-lockfile
  )
  log "cargo generate-lockfile done"
elif [ ! -f "${LOCK_PATH}" ]; then
  log "Cargo.lock missing; generating"
  (
    cd "${PROTO_DIR}"
    cargo generate-lockfile
  )
else
  log "Cargo.lock usable ($(wc -l < "${LOCK_PATH}") lines); git_checkout=${checkout_ok}"
fi

log "=== 3) stop selected services ==="
bash "${SCRIPT_DIR}/stop_all.sh" cplusbook encoding rust-compile WestChina hub || true

log "=== 4) start local services (SKIP_TUNNEL=1) ==="
SKIP_TUNNEL=1 bash "${SCRIPT_DIR}/start_all.sh" cplusbook encoding rust-compile WestChina hub

log "=== 5) status ==="
bash "${SCRIPT_DIR}/status_all.sh" || true

echo
echo "Listening TCP ports (ss):"
if command -v ss >/dev/null 2>&1; then
  ss -tlnp 2>/dev/null | grep -E ':(18200|3000|4001|5000|5175|18080|8080)\s' || ss -tlnp 2>/dev/null | head -n 40
else
  netstat -tlnp 2>/dev/null | head -n 40 || true
fi

log "done. Re-enable tunnels later with: bash start_all.sh cplusbook encoding rust-compile WestChina hub"
