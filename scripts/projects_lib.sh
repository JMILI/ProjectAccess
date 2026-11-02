#!/usr/bin/env bash
# Shared helpers for ProjectAccess orchestration scripts.

PROJECT_ACCESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_ROOT="$(cd "${PROJECT_ACCESS_DIR}/.." && pwd)"
CODE_JM_ROOT="$(cd "${DEPLOY_ROOT}/.." && pwd)"
# 风声有两份（均已回退到未重组目录的 abe704a 版本，原型在 design/03-vue-prototype）：
#   fengsheng     -> 仓库旁路 code_jm/fengsheng/design/03-vue-prototype（原项目，5173）
#   fengsheng-dev -> deployProject/fengsheng/design/03-vue-prototype（二次开发副本，5178）
#   说明：后台管理原型（design/04-admin-prototype，5179）不纳入编排，单独启动。
FENGSHENG_DIR="${FENGSHENG_DIR:-${CODE_JM_ROOT}/fengsheng/design/03-vue-prototype}"
FENGSHENG_DEV_DIR="${FENGSHENG_DEV_DIR:-${DEPLOY_ROOT}/fengsheng/design/03-vue-prototype}"
RUN_DIR="${PROJECT_ACCESS_DIR}/.run"

# Prefer the rustup toolchain over distro cargo/rustc: several projects ship
# Cargo.lock v4, which the distro cargo (1.75) cannot parse.
if [ -x "${HOME}/.cargo/bin/cargo" ]; then
  case ":$PATH:" in
    *":${HOME}/.cargo/bin:"*) ;;
    *) PATH="${HOME}/.cargo/bin:${PATH}"; export PATH ;;
  esac
fi

mkdir -p "$RUN_DIR"

# Network layer: keep local ports + Sealos/sealtun off the Windows HTTP proxy.
# VPN on/off must not break 127.0.0.1 preview or tunnel control plane.
if [ -f "${CODE_JM_ROOT}/devnet/lib/proxy.sh" ]; then
  # shellcheck source=/dev/null
  source "${CODE_JM_ROOT}/devnet/lib/proxy.sh"
  # Only ensure NO_PROXY here; do not force proxy on/off mid-script (user/shell owns that).
  export NO_PROXY="$(devnet_no_proxy_list)"
  export no_proxy="$NO_PROXY"
fi

log() {
  echo "[$(date '+%H:%M:%S')] $*"
}

port_listening() {
  ss -tln 2>/dev/null | grep -q ":${1} "
}

wait_port() {
  local port="$1"
  local timeout="${2:-60}"
  local label="${3:-:${port}}"
  local i
  log "waiting for ${label} (up to ${timeout}s)..."
  for ((i = 1; i <= timeout; i++)); do
    if port_listening "$port"; then
      log "ready ${label} (${i}s)"
      return 0
    fi
    # Heartbeat so long waits (WestChina/wisdom) do not look hung.
    if (( i % 10 == 0 )); then
      log "still waiting ${label}... ${i}/${timeout}s (detail: ${RUN_DIR}/*.log)"
    fi
    sleep 1
  done
  log "WARN: timeout waiting for ${label} (see ${RUN_DIR})"
  return 1
}

read_pid() {
  local file="${RUN_DIR}/${1}.pid"
  if [ -f "$file" ]; then
    cat "$file"
  fi
}

write_pid() {
  echo "$2" > "${RUN_DIR}/${1}.pid"
}

remove_pid() {
  rm -f "${RUN_DIR}/${1}.pid"
}

stop_pid() {
  local name="$1"
  local pid
  pid="$(read_pid "$name")"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    local i
    for ((i = 1; i <= 20; i++)); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.25
    done
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
    log "stopped ${name} (pid ${pid})"
  fi
  remove_pid "$name"
}

pids_on_port() {
  local port="$1"
  ss -tlnp 2>/dev/null | awk -v p=":${port}" '$4 ~ p {print $NF}' \
    | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | sort -u
}

kill_port() {
  local port="$1"
  local pid i
  for pid in $(pids_on_port "$port"); do
    kill "$pid" 2>/dev/null || true
  done
  # pids_on_port 依赖 ss -p 的可见性；进程若是别的用户（例如以前用 root 起过）看不到，
  # 这里用 fuser 兜底，并在端口仍被占用时明确报错而不是静默成功。
  for i in 1 2 3 4 5; do
    port_listening "$port" || return 0
    sleep 0.4
  done
  if command -v fuser >/dev/null 2>&1; then
    fuser -k -TERM "${port}/tcp" >/dev/null 2>&1 || true
    sleep 0.6
    port_listening "$port" || return 0
    fuser -k -KILL "${port}/tcp" >/dev/null 2>&1 || true
    sleep 0.4
    port_listening "$port" || return 0
  fi
  log "WARN: 端口 ${port} 仍被占用（可能是别的用户/root 起的进程，请用 sudo 或重启 WSL 释放）"
  return 1
}

kill_port_hard() {
  local port="$1"
  local pid
  for pid in $(pids_on_port "$port"); do
    kill -9 "$pid" 2>/dev/null || true
  done
}

start_bg() {
  local name="$1"
  local dir="$2"
  shift 2
  local logfile="${RUN_DIR}/${name}.log"
  stop_pid "$name"
  cd "$dir" || return 1
  # setsid: leave the launching session so a wrapper (npm/bash/java launcher)
  # cannot take the real server down with it when the orchestrator exits.
  setsid nohup "$@" >>"$logfile" 2>&1 </dev/null &
  write_pid "$name" "$!"
  log "started ${name} (pid $!) log=${logfile}"
}

normalize_project() {
  case "$1" in
    hub | project-access | ProjectAccess) echo "hub" ;;
    wisdom) echo "wisdom" ;;
    westchina | westChina | WestChina | WestChina-Cloud) echo "westchina" ;;
    encoding | encoding_practice) echo "encoding" ;;
    cplusbook | cPlusBook) echo "cplusbook" ;;
    offer | offerPDF) echo "offer" ;;
    rust-compile | rust-compile-web) echo "rust-compile" ;;
    fengsheng | fengsheng-vue | 风声) echo "fengsheng" ;;
    fengsheng-dev | fengsheng_dev | 风声-dev | 风声副本) echo "fengsheng-dev" ;;
    rust-thread | rust-thread-async-memory | rustThread | rust-memory | rust-memory-layout) echo "rust-thread" ;;
    *) echo "$1" ;;
  esac
}

ALL_PROJECTS=(hub wisdom westchina encoding cplusbook offer rust-compile fengsheng fengsheng-dev rust-thread)
LIGHT_PROJECTS=(hub offer cplusbook encoding rust-compile fengsheng fengsheng-dev rust-thread)

should_run_project() {
  local name="$1"
  local mode="$2"
  shift 2
  local -a selected=("$@")

  local item
  if [ "${#selected[@]}" -gt 0 ]; then
    for item in "${selected[@]}"; do
      if [ "$(normalize_project "$item")" = "$name" ]; then
        return 0
      fi
    done
    return 1
  fi

  case "$mode" in
    light)
      for item in "${LIGHT_PROJECTS[@]}"; do
        [ "$item" = "$name" ] && return 0
      done
      return 1
      ;;
    all | *)
      return 0
      ;;
  esac
}

print_port_status() {
  local name="$1"
  local port="$2"
  local url="${3:-http://127.0.0.1:${port}/}"
  if port_listening "$port"; then
    local code
    # --noproxy '*': never send local health checks through Clash/VPN proxy
    code="$(curl -s -o /dev/null -w '%{http_code}' -m 3 --noproxy '*' "$url" 2>/dev/null || echo "---")"
    printf "  %-18s :%-5s  OK (%s)  %s\n" "$name" "$port" "$code" "$url"
  else
    printf "  %-18s :%-5s  DOWN\n" "$name" "$port"
  fi
}

# project -> "tunnel_name:local_port"
tunnel_spec_for_project() {
  case "$(normalize_project "$1")" in
    hub) echo "project-access:18200" ;;
    wisdom) echo "wisdom-ui:9527" ;;
    westchina) echo "westchina-ui:5000" ;;
    encoding) echo "encoding-practice-web:3000" ;;
    cplusbook) echo "cplusbook-ui:4001" ;;
    offer) echo "offer-ui:4000" ;;
    rust-compile) echo "rust-compile-web-ui:5175" ;;
    fengsheng) echo "fengsheng-vue:5173" ;;
    fengsheng-dev) echo "fengsheng-dev:5178" ;;
    rust-thread) echo "rust-thread-async-memory-ui:5180" ;;
    *) return 1 ;;
  esac
}

resolve_sealtun_cmd() {
  if command -v sealtun >/dev/null 2>&1; then
    echo "sealtun"
    return 0
  fi
  if command -v npx >/dev/null 2>&1; then
    echo "npx sealtun"
    return 0
  fi
  return 1
}

sealtun_logged_in() {
  local cmd
  cmd="$(resolve_sealtun_cmd)" || return 1
  # shellcheck disable=SC2086
  $cmd status 2>/dev/null | grep -q "Logged in: yes"
}

# Cached status blob for this ensure run (avoids repeated slow status calls).
SEALTUN_STATUS_CACHE=""

sealtun_status_blob() {
  local cmd
  if [ -n "${SEALTUN_STATUS_CACHE}" ]; then
    printf '%s\n' "$SEALTUN_STATUS_CACHE"
    return 0
  fi
  cmd="$(resolve_sealtun_cmd)" || return 1
  # shellcheck disable=SC2086
  SEALTUN_STATUS_CACHE="$(timeout 25 $cmd status 2>/dev/null || true)"
  printf '%s\n' "$SEALTUN_STATUS_CACHE"
}

# Soft preflight: "Logged in: yes" is necessary but not sufficient
# (expired tokens still show Logged in; billing drain shows Workspace unavailable).
sealtun_auth_usable() {
  local blob
  blob="$(sealtun_status_blob)" || return 1
  echo "$blob" | grep -q "Logged in: yes" || return 1
  if echo "$blob" | grep -qi "Workspace: unavailable"; then
    return 1
  fi
  return 0
}

# Default: tunnels are required with local start/stop.
# Opt out only with SKIP_TUNNEL=1 (start) or KEEP_TUNNEL=1 (stop).
tunnels_required() {
  [ "${SKIP_TUNNEL:-0}" != "1" ] && [ "${KEEP_TUNNEL:-0}" != "1" ]
}

# Preflight for starting tunnels. Returns 0 if OK to proceed.
# When tunnels are required, prints ERROR (not soft WARN) and returns 1.
#
# NOTE: sealtun status prints "Workspace: unavailable" when auth.json has no
# current_workspace metadata — that is NOT a live billing probe. After recharge,
# Namespace (kubeconfig) can still be valid and tunnels can start. Gate on login
# + Namespace instead of that display string alone.
sealtun_preflight_for_start() {
  local blob
  if [ "${SKIP_TUNNEL:-0}" = "1" ]; then
    log "SKIP_TUNNEL=1 — tunnels not required this run"
    return 0
  fi

  blob="$(sealtun_status_blob 2>/dev/null || true)"
  if [ -z "$blob" ]; then
    log "ERROR: sealtun status unavailable (timeout/network)"
    log "ERROR: need reachability to https://gzg.sealos.run then: sealtun login gzg"
    log "ERROR: or local-only: SKIP_TUNNEL=1 bash start_all.sh ..."
    return 1
  fi
  if ! echo "$blob" | grep -q "Logged in: yes"; then
    log "ERROR: sealtun not logged in — run: sealtun login gzg"
    log "ERROR: or local-only: SKIP_TUNNEL=1 bash start_all.sh ..."
    return 1
  fi

  # Prefer real kube/namespace signal over the display-only Workspace line.
  if echo "$blob" | grep -qiE 'Namespace:[[:space:]]+ns-'; then
    if echo "$blob" | grep -qi "Workspace: unavailable"; then
      log "NOTE: status shows Workspace: unavailable (missing login metadata) but Namespace is set — continuing tunnels"
    fi
    return 0
  fi

  if echo "$blob" | grep -qi "Workspace: unavailable"; then
    log "ERROR: Sealos Workspace unavailable and no Namespace in sealtun status"
    log "ERROR: recharge https://gzg.sealos.run then: sealtun login gzg  (expect a 'Logged in to workspace: ns-...' line)"
    log "ERROR: or local-only: SKIP_TUNNEL=1 bash start_all.sh ..."
    return 1
  fi
  return 0
}

# Backward-compatible alias used by older call sites.
sealtun_preflight_warn() {
  sealtun_preflight_for_start
}

sealtun_list_cached() {
  local cmd
  cmd="$(resolve_sealtun_cmd)" || return 1
  # shellcheck disable=SC2086
  timeout 40 $cmd list 2>/dev/null || true
}

# Return status for tunnel name from a `sealtun list` blob: active|stale|stopped|missing
sealtun_tunnel_status() {
  local list_out="$1"
  local name="$2"
  echo "$list_out" | awk -v n="$name" '
    $1 == n {
      for (i = 1; i <= NF; i++) {
        if ($i == "active" || $i == "stale" || $i == "stopped" || $i == "inactive") {
          print $i
          exit
        }
      }
      print "unknown"
      exit
    }
  '
}

# Public URL hint (fixed Sealos naming).
tunnel_public_url() {
  local name="$1"
  echo "https://sealtun-${name}-ns-km83ebvo.sealosgzg.site/"
}

# Restart sealtun daemon when old sessions are stale (common after WSL sleep / Ctrl+C).
maybe_restart_sealtun_daemon() {
  local cmd="$1"
  local list_out="$2"
  local -a need_names=("${@:3}")
  local name status need_restart=0

  if [ "${RESTART_SEALTUN:-auto}" = "0" ]; then
    return 0
  fi

  for name in "${need_names[@]}"; do
    status="$(sealtun_tunnel_status "$list_out" "$name")"
    if [ "$status" = "stale" ] || [ "$status" = "stopped" ]; then
      need_restart=1
      break
    fi
  done

  if [ "$need_restart" = "0" ] && [ "${RESTART_SEALTUN:-auto}" != "1" ]; then
    return 0
  fi

  log "restart sealtun daemon (clear stale sessions)"
  pkill -f '[s]ealtun' 2>/dev/null || true
  sleep 2
  rm -f "${HOME}/.sealtun/daemon.runtime.lock" 2>/dev/null || true
  # Warm daemon so subsequent `start` does not race a dead PID.
  # shellcheck disable=SC2086
  # 必须 setsid+nohup 脱离控制终端，否则脚本/会话退出时 daemon 会被一起带走（隧道全部变 502）
  setsid nohup $cmd daemon >>"${RUN_DIR}/sealtun-ensure.log" 2>&1 </dev/null &
  sleep 2
  SEALTUN_STATUS_CACHE=""
  # shellcheck disable=SC2086
  $cmd status >>"${RUN_DIR}/sealtun-ensure.log" 2>&1 || true
}

# Recreate one tunnel (cleanup local/remote session then apply).
# Used when start fails with Unauthorized / error after billing recovery.
recreate_project_tunnel() {
  local cmd="$1"
  local name="$2"
  local port="$3"
  local logfile="$4"
  local tmp

  log "recreate tunnel ${name} (:${port}) via cleanup+apply"
  # shellcheck disable=SC2086
  $cmd cleanup "$name" >>"$logfile" 2>&1 || true
  sleep 1
  tmp="$(mktemp)"
  cat >"$tmp" <<EOF
version: v1
tunnels:
  - name: ${name}
    localPort: ${port}
    protocol: https
EOF
  # shellcheck disable=SC2086
  if ! $cmd apply -f "$tmp" >>"$logfile" 2>&1; then
    rm -f "$tmp"
    log "WARN: apply ${name} failed — see ${logfile}"
    return 1
  fi
  rm -f "$tmp"
  # shellcheck disable=SC2086
  $cmd start "$name" >>"$logfile" 2>&1 || true
  return 0
}

wait_tunnel_active() {
  local name="$1"
  local max_sec="${2:-90}"
  local waited=0
  local list_out status
  while [ "$waited" -lt "$max_sec" ]; do
    list_out="$(sealtun_list_cached)"
    status="$(sealtun_tunnel_status "$list_out" "$name")"
    if [ "$status" = "active" ]; then
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
  done
  return 1
}

# Start tunnels for selected projects.
# - Prefer sealtun start for existing sessions (keeps fixed domain)
# - Missing tunnels: apply then start
# - start Unauthorized/error: cleanup+apply recreate (do NOT abort whole batch)
# - Never wrap sealtun start in GNU timeout
# Returns 0 only when every needed tunnel is active (or SKIP_TUNNEL=1).
ensure_selected_tunnels() {
  local mode="$1"
  shift
  local -a selected=("$@")
  local project spec name port cmd
  local list_out status start_out
  local -a need_names=()
  local -a need_ports=()
  local i logfile ok=0 expected=0

  if [ "${SKIP_TUNNEL:-0}" = "1" ]; then
    log "SKIP_TUNNEL=1, skip sealtun"
    return 0
  fi

  cmd="$(resolve_sealtun_cmd)" || {
    log "ERROR: sealtun not installed (npm i -g sealtun)"
    return 1
  }

  SEALTUN_STATUS_CACHE=""
  if ! sealtun_preflight_for_start; then
    return 1
  fi

  log "=== sealtun tunnels for selected projects ==="
  mkdir -p "${RUN_DIR}"
  logfile="${RUN_DIR}/sealtun-ensure.log"
  : >"$logfile"

  for project in "${ALL_PROJECTS[@]}"; do
    if ! should_run_project "$project" "$mode" "${selected[@]}"; then
      continue
    fi
    spec="$(tunnel_spec_for_project "$project")" || continue
    name="${spec%%:*}"
    port="${spec##*:}"
    expected=$((expected + 1))
    if ! port_listening "$port"; then
      log "ERROR: tunnel ${name} needs local :${port} UP first — local start incomplete"
      continue
    fi
    need_names+=("$name")
    need_ports+=("$port")
  done

  if [ "${#need_names[@]}" -eq 0 ]; then
    log "ERROR: no local ports ready to tunnel (${expected} projects selected)"
    return 1
  fi

  list_out="$(sealtun_list_cached)"
  maybe_restart_sealtun_daemon "$cmd" "$list_out" "${need_names[@]}"
  list_out="$(sealtun_list_cached)"

  for i in "${!need_names[@]}"; do
    name="${need_names[$i]}"
    port="${need_ports[$i]}"
    status="$(sealtun_tunnel_status "$list_out" "$name")"

    if [ "$status" = "active" ]; then
      log "tunnel ${name} already active (:${port})"
      ok=$((ok + 1))
      continue
    fi

    if [ -z "$status" ]; then
      log "tunnel ${name} missing locally — apply"
      if recreate_project_tunnel "$cmd" "$name" "$port" "$logfile"; then
        if wait_tunnel_active "$name" 120; then
          log "tunnel ${name} active"
          ok=$((ok + 1))
        else
          log "ERROR: tunnel ${name} applied but not active — see ${logfile}"
        fi
      fi
      list_out="$(sealtun_list_cached)"
      continue
    fi

    log "start tunnel ${name} (was ${status}, :${port})"
    # shellcheck disable=SC2086
    start_out="$($cmd start "$name" 2>&1)" || true
    printf '%s\n' "$start_out" >>"$logfile"

    if wait_tunnel_active "$name" 45; then
      log "tunnel ${name} active"
      ok=$((ok + 1))
      list_out="$(sealtun_list_cached)"
      continue
    fi

    log "WARN: start ${name} failed; recreating (cleanup+apply)"
    if echo "$start_out" | grep -qi 'Unauthorized\|re-login\|permission'; then
      log "NOTE: Unauthorized on ${name} — recreating after possible billing reclaim"
    fi
    if recreate_project_tunnel "$cmd" "$name" "$port" "$logfile"; then
      if wait_tunnel_active "$name" 120; then
        log "tunnel ${name} active"
        ok=$((ok + 1))
      else
        log "ERROR: tunnel ${name} still not active — see ${logfile}"
      fi
    fi
    list_out="$(sealtun_list_cached)"
  done

  list_out="$(sealtun_list_cached)"
  echo "----------------------------------------"
  echo "Tunnel endpoints (selected):"
  for i in "${!need_names[@]}"; do
    name="${need_names[$i]}"
    status="$(sealtun_tunnel_status "$list_out" "$name")"
    status="${status:-missing}"
    printf "  %-24s %-8s %s\n" "$name" "$status" "$(tunnel_public_url "$name")"
  done
  log "tunnel ensure done (${ok}/${#need_names[@]} active); log=${logfile}"
  if [ "$ok" -lt "${#need_names[@]}" ]; then
    log "ERROR: not all tunnels active (${ok}/${#need_names[@]})"
    return 1
  fi
  return 0
}

# Stop sealtun tunnels for selected projects (best-effort).
# Skip with KEEP_TUNNEL=1 or SKIP_TUNNEL=1.
stop_selected_tunnels() {
  local mode="$1"
  shift
  local -a selected=("$@")
  local project spec name cmd list_out

  if [ "${KEEP_TUNNEL:-0}" = "1" ] || [ "${SKIP_TUNNEL:-0}" = "1" ]; then
    log "KEEP_TUNNEL/SKIP_TUNNEL set — leave sealtun tunnels running"
    return 0
  fi

  cmd="$(resolve_sealtun_cmd)" || {
    log "WARN: sealtun not installed — cannot stop tunnels"
    return 0
  }

  log "=== stop sealtun tunnels for selected projects ==="
  list_out="$(timeout 40 $cmd list 2>/dev/null || true)"
  for project in "${ALL_PROJECTS[@]}"; do
    if ! should_run_project "$project" "$mode" "${selected[@]}"; then
      continue
    fi
    spec="$(tunnel_spec_for_project "$project")" || continue
    name="${spec%%:*}"
    if [ -z "$list_out" ] || ! echo "$list_out" | awk 'NR>1 {print $1}' | grep -qx "$name"; then
      log "tunnel ${name}: not in local list (skip)"
      continue
    fi
    log "stop tunnel ${name}"
    # shellcheck disable=SC2086
    $cmd stop "$name" >>"${RUN_DIR}/sealtun-stop.log" 2>&1 || true
  done
}

# Expected local port for a project (primary UI/API port we wait on).
local_port_for_project() {
  case "$1" in
    hub) echo "18200" ;;
    wisdom) echo "9527" ;;
    westchina) echo "5000" ;;
    encoding) echo "3000" ;;
    cplusbook) echo "4001" ;;
    offer) echo "4000" ;;
    rust-compile) echo "5175" ;;
    fengsheng) echo "5173" ;;
    fengsheng-dev) echo "5178" ;;
    rust-thread) echo "5180" ;;
    *) return 1 ;;
  esac
}

# Verify every selected project has its local port listening. Returns 0 if all OK.
verify_selected_locals() {
  local mode="$1"
  shift
  local -a selected=("$@")
  local project port missing=0

  echo "----------------------------------------"
  echo "Local ports (selected):"
  for project in "${ALL_PROJECTS[@]}"; do
    if ! should_run_project "$project" "$mode" "${selected[@]}"; then
      continue
    fi
    port="$(local_port_for_project "$project")" || continue
    if port_listening "$port"; then
      printf "  %-16s :%-5s OK\n" "$project" "$port"
    else
      printf "  %-16s :%-5s DOWN\n" "$project" "$port"
      missing=$((missing + 1))
    fi
  done
  if [ "$missing" -gt 0 ]; then
    log "ERROR: ${missing} selected local service(s) still DOWN"
    return 1
  fi
  return 0
}
