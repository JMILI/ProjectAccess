#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/projects_lib.sh
source "${SCRIPT_DIR}/scripts/projects_lib.sh"

MODE="${1:-all}"
shift || true

if [ "$MODE" = "help" ] || [ "$MODE" = "-h" ] || [ "$MODE" = "--help" ]; then
  cat <<'EOF'
Usage: bash start_all.sh [all|light] [project...]

Modes:
  all    Start ProjectAccess hub + all managed projects (default)
  light  Start hub + light projects (skip wisdom & WestChina)

Projects (optional filter):
  hub, wisdom, westchina, encoding, cplusbook, offer, rust-compile, fengsheng

After local services are ready, matching Sealtun tunnels are started
(so both localhost and sealtun-*.sealosgzg.site work). Requires:
  sealtun login gzg   # once

Environment:
  SKIP_TUNNEL=1      Only start local services (skip sealtun)
  RESTART_SEALTUN=1  Force-restart sealtun daemon before starting tunnels

If tunnels stay stale / Unauthorized:
  sealtun login gzg
  RESTART_SEALTUN=1 bash start_all.sh cplusbook encoding rust-compile WestChina fengsheng hub

Examples:
  bash start_all.sh
  bash start_all.sh light
  bash start_all.sh hub offer cplusbook
  RESTART_SEALTUN=1 bash start_all.sh cplusbook encoding rust-compile WestChina fengsheng hub
  SKIP_TUNNEL=1 bash start_all.sh light

Logs & pid files: ProjectAccess/.run/
EOF
  exit 0
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "light" ]; then
  SELECT=("$@")
else
  SELECT=("$MODE" "$@")
  MODE="all"
fi

log "mode=${MODE} deploy_root=${DEPLOY_ROOT}"
log "run_dir=${RUN_DIR}"

start_wisdom() {
  log "=== wisdom (port 9527) ==="
  if port_listening 9527; then
    log "wisdom frontend already listening on 9527, skip"
    return 0
  fi
  (
    cd "${DEPLOY_ROOT}/wisdom"
    bash start_all.sh core
  ) >>"${RUN_DIR}/wisdom.log" 2>&1 &
  write_pid wisdom "$!"
  wait_port 9527 180 "wisdom:9527" || true
}

start_westchina() {
  log "=== WestChina-Cloud (port 5000) ==="
  if port_listening 5000; then
    log "WestChina UI already listening on 5000, skip"
    return 0
  fi
  (
    cd "${DEPLOY_ROOT}/WestChina-Cloud"
    SEALTUN_AUTO_START=0 bash start_all.sh core
  ) >>"${RUN_DIR}/westchina.log" 2>&1 &
  write_pid westchina "$!"
  wait_port 5000 180 "westchina:5000" || true
}

start_encoding() {
  log "=== encoding_practice (port 3000) ==="
  if port_listening 3000; then
    log "encoding_practice already listening on 3000, skip"
    return 0
  fi
  start_bg encoding "${DEPLOY_ROOT}/encoding_practice/protocol_tutorial" \
    cargo run --bin web
  wait_port 3000 90 "encoding:3000" || true
}

start_cplusbook() {
  log "=== cPlusBook (port 4001, mdBook static) ==="
  local dir="${DEPLOY_ROOT}/cPlusBook"
  local serve_dir="${dir}/book"

  if [ ! -f "${serve_dir}/index.html" ]; then
    log "building mdBook (first run may download mdbook)..."
    (cd "$dir" && bash build.sh) >>"${RUN_DIR}/cplusbook-build.log" 2>&1
  fi

  if [ ! -f "${serve_dir}/index.html" ]; then
    log "ERROR: mdBook build failed, see ${RUN_DIR}/cplusbook-build.log"
    return 1
  fi

  if port_listening 4001; then
    log "cPlusBook already listening on 4001, skip"
    return 0
  fi
  start_bg cplusbook "$serve_dir" \
    python3 -m http.server 4001 --bind 0.0.0.0
  wait_port 4001 15 "cplusbook:4001" || true
}

start_offer() {
  log "=== offer (port 4000, Axum + MySQL API) ==="
  local dir="${DEPLOY_ROOT}/offer"
  cp -f "${dir}/resume.html" "${dir}/index.html"

  if port_listening 4000; then
    log "offer already listening on 4000, skip"
    return 0
  fi
  # 使用 resume-viewer（静态页 + /api/resumes），勿再起 python http.serve
  start_bg offer "$dir" \
    env OPEN_BROWSER=0 HOST=0.0.0.0 PORT=4000 cargo run --quiet
  wait_port 4000 60 "offer:4000" || true
}

start_rust_compile() {
  # Use 5175 so it does not collide with fengsheng Vue prototype on 5173.
  log "=== rust-compile-web (5175 + backend) ==="
  local backend_port="${RUST_COMPILE_BACKEND_PORT:-}"
  if [ -z "$backend_port" ]; then
    if port_listening 8080; then
      backend_port=18080
    else
      backend_port=8080
    fi
  fi

  if ! port_listening "$backend_port"; then
    start_bg rust-backend "${DEPLOY_ROOT}/rust-compile-web/backend" \
      env PORT="${backend_port}" cargo run
    wait_port "$backend_port" 120 "rust-backend:${backend_port}" || true
  else
    log "rust-compile backend already on ${backend_port}, skip"
  fi

  if port_listening 5175; then
    log "rust-compile frontend already on 5175, skip"
    return 0
  fi

  local proxy_target="http://127.0.0.1:${backend_port}"
  start_bg rust-frontend "${DEPLOY_ROOT}/rust-compile-web/frontend" \
    env VITE_PROXY_TARGET="${proxy_target}" npm run dev -- --host 0.0.0.0 --port 5175
  wait_port 5175 60 "rust-frontend:5175" || true
}

start_fengsheng() {
  # Vue prototype under code_jm/fengsheng (not deployProject/)
  log "=== fengsheng Vue prototype (port 5173) ==="
  local dir="${FENGSHENG_DIR}"
  if [ ! -d "$dir" ]; then
    log "ERROR: fengsheng dir missing: ${dir}"
    return 1
  fi
  if [ ! -d "${dir}/node_modules" ]; then
    log "npm install (first run)..."
    (cd "$dir" && npm install) >>"${RUN_DIR}/fengsheng-npm.log" 2>&1 || {
      log "ERROR: npm install failed, see ${RUN_DIR}/fengsheng-npm.log"
      return 1
    }
  fi
  if port_listening 5173; then
    log "fengsheng already listening on 5173, skip"
    return 0
  fi
  start_bg fengsheng "$dir" \
    npm run dev -- --host 0.0.0.0 --port 5173
  wait_port 5173 60 "fengsheng:5173" || true
}

start_hub() {
  log "=== ProjectAccess hub (port 18200) ==="
  if port_listening 18200; then
    log "ProjectAccess already listening on 18200, skip"
    return 0
  fi
  (
    cd "${PROJECT_ACCESS_DIR}"
    cargo build --release >/dev/null
    nohup env PORT=18200 ./target/release/ProjectAccess >>"${RUN_DIR}/hub.log" 2>&1 &
    echo $! >"${RUN_DIR}/hub.pid"
  )
  wait_port 18200 30 "hub:18200" || true
}

if should_run_project wisdom "$MODE" "${SELECT[@]}"; then start_wisdom; fi
if should_run_project westchina "$MODE" "${SELECT[@]}"; then start_westchina; fi
if should_run_project encoding "$MODE" "${SELECT[@]}"; then start_encoding; fi
if should_run_project cplusbook "$MODE" "${SELECT[@]}"; then start_cplusbook; fi
if should_run_project offer "$MODE" "${SELECT[@]}"; then start_offer; fi
if should_run_project rust-compile "$MODE" "${SELECT[@]}"; then start_rust_compile; fi
if should_run_project fengsheng "$MODE" "${SELECT[@]}"; then start_fengsheng; fi
if should_run_project hub "$MODE" "${SELECT[@]}"; then start_hub; fi

# Local services ready → restore/create only the tunnels for selected projects
# (per-tunnel apply avoids full sealtun.yaml timeout when other ports are down).
ensure_selected_tunnels "$MODE" "${SELECT[@]}" || true

log "=== start_all done ==="
bash "${SCRIPT_DIR}/status_all.sh"
