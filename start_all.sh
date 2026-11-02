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

Default behavior: start LOCAL services + matching Sealtun TUNNELS together.
Exit code 0 only when every selected local port is UP and every tunnel is active
(unless you opt out of tunnels).

Modes:
  all    Start ProjectAccess hub + all managed projects (default)
  light  Start hub + light projects (skip wisdom & WestChina)

Projects (optional filter):
  hub, wisdom, westchina, encoding, cplusbook, offer, rust-compile, fengsheng, fengsheng-dev, rust-thread
  (default `all` = 上述列表去掉 wisdom；wisdom 需要显式指定)

Environment:
  SKIP_TUNNEL=1      Local only (explicit opt-out of tunnels)
  RESTART_SEALTUN=1  Force-restart sealtun daemon before tunnels
  ALLOW_PARTIAL=1    Do not fail the script if some locals/tunnels are down

Requires for tunnels: sealtun login gzg  + Sealos Workspace available

Examples:
  bash start_all.sh cplusbook encoding rust-compile WestChina fengsheng hub
  SKIP_TUNNEL=1 bash start_all.sh cplusbook encoding rust-compile WestChina fengsheng hub
  bash start_all.sh light

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

# 默认 all：只带 9 个已恢复的项目（8 个 hub 卡片 + fengsheng-dev 副本）；wisdom 已删除，
# 需要时显式 `bash start_all.sh wisdom` 再试，避免默认流程被它拖成 incomplete。
DEFAULT_PROJECTS=(hub westchina encoding cplusbook offer rust-compile fengsheng fengsheng-dev rust-thread)
if [ "${#SELECT[@]}" -eq 0 ] && { [ "$MODE" = "all" ] || [ "$MODE" = "light" ]; }; then
  SELECT=("${DEFAULT_PROJECTS[@]}")
  log "note: wisdom 已删除（deployProject/wisdom 只有 front/），默认跳过；如已恢复可显式指定 wisdom"
fi

LOCAL_FAIL=0
TUNNEL_FAIL=0

require_port() {
  local port="$1"
  local label="$2"
  if port_listening "$port"; then
    return 0
  fi
  log "ERROR: ${label} failed to come up on :${port}"
  LOCAL_FAIL=$((LOCAL_FAIL + 1))
  return 1
}

log "mode=${MODE} deploy_root=${DEPLOY_ROOT}"
log "run_dir=${RUN_DIR}"
if [ "${SKIP_TUNNEL:-0}" = "1" ]; then
  log "policy: LOCAL only (SKIP_TUNNEL=1)"
else
  log "policy: LOCAL + TUNNEL (default). Opt out with SKIP_TUNNEL=1"
fi

start_wisdom() {
  log "=== wisdom (port 9527) ==="
  if port_listening 9527; then
    log "wisdom frontend already listening on 9527, skip"
    return 0
  fi
  log "starting wisdom core in background (often 1–3 min); log: ${RUN_DIR}/wisdom.log"
  (
    cd "${DEPLOY_ROOT}/wisdom"
    exec setsid bash start_all.sh core
  ) >>"${RUN_DIR}/wisdom.log" 2>&1 &
  write_pid wisdom "$!"
  wait_port 9527 180 "wisdom:9527" || true
  require_port 9527 "wisdom"
}

start_westchina() {
  log "=== WestChina-Cloud (port 5000) ==="
  if port_listening 5000; then
    log "WestChina UI already listening on 5000, skip"
    return 0
  fi
  log "starting WestChina core in background (Docker + Java + UI; often 1–3 min)"
  log "live log: tail -f ${RUN_DIR}/westchina.log"
  (
    cd "${DEPLOY_ROOT}/WestChina-Cloud"
    exec setsid env SEALTUN_AUTO_START=0 bash start_all.sh core
  ) >>"${RUN_DIR}/westchina.log" 2>&1 &
  write_pid westchina "$!"
  # Cold boot (Docker + many Java services + UI) often exceeds 3 minutes.
  wait_port 5000 "${WESTCHINA_WAIT_SEC:-360}" "westchina:5000" || true
  require_port 5000 "westchina"
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
  require_port 3000 "encoding"
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
    LOCAL_FAIL=$((LOCAL_FAIL + 1))
    return 1
  fi

  if port_listening 4001; then
    log "cPlusBook already listening on 4001, skip"
    return 0
  fi
  start_bg cplusbook "$serve_dir" \
    python3 -m http.server 4001 --bind 0.0.0.0
  wait_port 4001 15 "cplusbook:4001" || true
  require_port 4001 "cplusbook"
}

start_offer() {
  log "=== offer (port 4000, Axum + MySQL API) ==="
  local dir="${DEPLOY_ROOT}/offer"
  # NOTE: index.html ships as the workbench hub (not a copy of resume.html);
  # do not overwrite it here.

  if port_listening 4000; then
    log "offer already listening on 4000, skip"
    return 0
  fi
  start_bg offer "$dir" \
    env OPEN_BROWSER=0 HOST=0.0.0.0 PORT=4000 cargo run --quiet
  wait_port 4000 90 "offer:4000" || true
  require_port 4000 "offer"
}

start_rust_compile() {
  # Frontend on 5175. Backend defaults to 18080 to avoid WestChina gateway :8080.
  log "=== rust-compile-web (5175 + backend) ==="
  local backend_port="${RUST_COMPILE_BACKEND_PORT:-18080}"

  if ! port_listening "$backend_port"; then
    start_bg rust-backend "${DEPLOY_ROOT}/rust-compile-web/backend" \
      env PORT="${backend_port}" cargo run
    wait_port "$backend_port" 120 "rust-backend:${backend_port}" || true
    require_port "$backend_port" "rust-backend"
  else
    log "rust-compile backend already on ${backend_port}, skip"
  fi

  if port_listening 5175; then
    log "rust-compile frontend already on 5175, skip"
    return 0
  fi

  local fe_dir="${DEPLOY_ROOT}/rust-compile-web/frontend"
  if [ ! -x "${fe_dir}/node_modules/.bin/vite" ]; then
    log "npm install rust-compile frontend (vite missing)..."
    (cd "$fe_dir" && npm install) >>"${RUN_DIR}/rust-frontend-npm.log" 2>&1 || {
      log "ERROR: npm install failed, see ${RUN_DIR}/rust-frontend-npm.log"
      LOCAL_FAIL=$((LOCAL_FAIL + 1))
      return 1
    }
  fi

  local proxy_target="http://127.0.0.1:${backend_port}"
  start_bg rust-frontend "$fe_dir" \
    env VITE_PROXY_TARGET="${proxy_target}" npm run dev -- --host 0.0.0.0 --port 5175
  wait_port 5175 90 "rust-frontend:5175" || true
  require_port 5175 "rust-frontend"
}

start_fengsheng() {
  log "=== fengsheng Vue prototype (frontend/prototype, port 5173) ==="
  local dir="${FENGSHENG_DIR}"
  if [ ! -d "$dir" ]; then
    log "ERROR: fengsheng dir missing: ${dir}"
    LOCAL_FAIL=$((LOCAL_FAIL + 1))
    return 1
  fi
  if [ ! -d "${dir}/node_modules" ]; then
    log "npm install (first run)..."
    (cd "$dir" && npm install) >>"${RUN_DIR}/fengsheng-npm.log" 2>&1 || {
      log "ERROR: npm install failed, see ${RUN_DIR}/fengsheng-npm.log"
      LOCAL_FAIL=$((LOCAL_FAIL + 1))
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
  require_port 5173 "fengsheng"
}

start_fengsheng_dev() {
  log "=== fengsheng-dev Vue prototype (design/03-vue-prototype 副本, port 5178) ==="
  local dir="${FENGSHENG_DEV_DIR}"
  if [ ! -d "$dir" ]; then
    log "ERROR: fengsheng-dev dir missing: ${dir}"
    LOCAL_FAIL=$((LOCAL_FAIL + 1))
    return 1
  fi
  if [ ! -d "${dir}/node_modules" ]; then
    log "npm install (fengsheng-dev first run)..."
    (cd "$dir" && npm install) >>"${RUN_DIR}/fengsheng-dev-npm.log" 2>&1 || {
      log "ERROR: npm install failed, see ${RUN_DIR}/fengsheng-dev-npm.log"
      LOCAL_FAIL=$((LOCAL_FAIL + 1))
      return 1
    }
  fi
  if port_listening 5178; then
    log "fengsheng-dev already listening on 5178, skip"
    return 0
  fi
  # 副本的 package.json dev 脚本写死了 --port 5173，这里直接调 vite 覆盖端口
  start_bg fengsheng-dev "$dir" \
    "${dir}/node_modules/.bin/vite" --host 0.0.0.0 --port 5178
  wait_port 5178 90 "fengsheng-dev:5178" || true
  require_port 5178 "fengsheng-dev"
}

start_rust_thread() {
  log "=== rust-thread-async-memory (port 5180) ==="
  local dir="${DEPLOY_ROOT}/rust-thread-async-memory"
  if [ ! -d "$dir" ]; then
    log "ERROR: rust-thread dir missing: ${dir}"
    LOCAL_FAIL=$((LOCAL_FAIL + 1))
    return 1
  fi
  if [ ! -x "${dir}/node_modules/.bin/vite" ]; then
    log "npm install rust-thread (first run)..."
    (cd "$dir" && npm install) >>"${RUN_DIR}/rust-thread-npm.log" 2>&1 || {
      log "ERROR: npm install failed, see ${RUN_DIR}/rust-thread-npm.log"
      LOCAL_FAIL=$((LOCAL_FAIL + 1))
      return 1
    }
  fi
  if port_listening 5180; then
    log "rust-thread already listening on 5180, skip"
    return 0
  fi
  start_bg rust-thread "$dir" \
    npm run dev -- --host 0.0.0.0 --port 5180
  wait_port 5180 90 "rust-thread:5180" || true
  require_port 5180 "rust-thread"
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
  require_port 18200 "hub"
}

# Light / fast first; heavy stacks last (progress keeps printing).
if should_run_project encoding "$MODE" "${SELECT[@]}"; then start_encoding || true; fi
if should_run_project cplusbook "$MODE" "${SELECT[@]}"; then start_cplusbook || true; fi
if should_run_project offer "$MODE" "${SELECT[@]}"; then start_offer || true; fi
if should_run_project rust-compile "$MODE" "${SELECT[@]}"; then start_rust_compile || true; fi
if should_run_project fengsheng "$MODE" "${SELECT[@]}"; then start_fengsheng || true; fi
if should_run_project fengsheng-dev "$MODE" "${SELECT[@]}"; then start_fengsheng_dev || true; fi
if should_run_project rust-thread "$MODE" "${SELECT[@]}"; then start_rust_thread || true; fi
if should_run_project hub "$MODE" "${SELECT[@]}"; then start_hub || true; fi
if should_run_project westchina "$MODE" "${SELECT[@]}"; then start_westchina || true; fi
if should_run_project wisdom "$MODE" "${SELECT[@]}"; then start_wisdom || true; fi

verify_selected_locals "$MODE" "${SELECT[@]}" || LOCAL_FAIL=$((LOCAL_FAIL + 1))

# Default: bring up tunnels for every selected project whose local port is up.
if ! ensure_selected_tunnels "$MODE" "${SELECT[@]}"; then
  TUNNEL_FAIL=1
fi

log "=== start_all done ==="
bash "${SCRIPT_DIR}/status_all.sh"

if [ "$LOCAL_FAIL" -gt 0 ] || [ "$TUNNEL_FAIL" -gt 0 ]; then
  log "RESULT: incomplete (local_fail=${LOCAL_FAIL} tunnel_fail=${TUNNEL_FAIL})"
  if [ "${ALLOW_PARTIAL:-0}" = "1" ]; then
    log "ALLOW_PARTIAL=1 — exiting 0 despite incomplete start"
    exit 0
  fi
  if [ "$TUNNEL_FAIL" -gt 0 ] && [ "${SKIP_TUNNEL:-0}" != "1" ]; then
    log "hint: fix Sealos (login/recharge) OR run with SKIP_TUNNEL=1 for local-only"
  fi
  exit 1
fi

log "RESULT: OK — selected locals UP and tunnels active (or SKIP_TUNNEL)"
exit 0
