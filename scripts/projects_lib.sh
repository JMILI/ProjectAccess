#!/usr/bin/env bash
# Shared helpers for ProjectAccess orchestration scripts.

PROJECT_ACCESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_ROOT="$(cd "${PROJECT_ACCESS_DIR}/.." && pwd)"
CODE_JM_ROOT="$(cd "${DEPLOY_ROOT}/.." && pwd)"
# 风声 Vue 原型不在 deployProject/ 下，而在仓库旁路 fengsheng/
FENGSHENG_DIR="${FENGSHENG_DIR:-${CODE_JM_ROOT}/fengsheng/design/03-vue-prototype}"
RUN_DIR="${PROJECT_ACCESS_DIR}/.run"

mkdir -p "$RUN_DIR"

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
  for ((i = 1; i <= timeout; i++)); do
    if port_listening "$port"; then
      log "ready ${label}"
      return 0
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
  local pid
  for pid in $(pids_on_port "$port"); do
    kill "$pid" 2>/dev/null || true
  done
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
  nohup "$@" >>"$logfile" 2>&1 &
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
    *) echo "$1" ;;
  esac
}

ALL_PROJECTS=(hub wisdom westchina encoding cplusbook offer rust-compile fengsheng)
LIGHT_PROJECTS=(hub offer cplusbook encoding rust-compile fengsheng)

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
    code="$(curl -s -o /dev/null -w '%{http_code}' -m 3 "$url" 2>/dev/null || echo "---")"
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
# (expired tokens still show Logged in). Hard fail happens on Unauthorized
# during `sealtun start` below.
sealtun_auth_usable() {
  local blob
  blob="$(sealtun_status_blob)" || return 1
  echo "$blob" | grep -q "Logged in: yes" || return 1
  return 0
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
  $cmd daemon >>"${RUN_DIR}/sealtun-ensure.log" 2>&1 &
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
ensure_selected_tunnels() {
  local mode="$1"
  shift
  local -a selected=("$@")
  local project spec name port cmd
  local list_out status start_out
  local -a need_names=()
  local -a need_ports=()
  local i tmp logfile ok=0

  if [ "${SKIP_TUNNEL:-0}" = "1" ]; then
    log "SKIP_TUNNEL=1, skip sealtun"
    return 0
  fi

  cmd="$(resolve_sealtun_cmd)" || {
    log "WARN: sealtun not installed, local-only (npm i -g sealtun)"
    return 0
  }

  SEALTUN_STATUS_CACHE=""
  if ! sealtun_logged_in; then
    log "WARN: sealtun not logged in — local OK, tunnels skipped"
    log "WARN: run once: sealtun login gzg"
    return 0
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
    if ! port_listening "$port"; then
      log "skip tunnel ${name}: local :${port} DOWN"
      continue
    fi
    need_names+=("$name")
    need_ports+=("$port")
  done

  if [ "${#need_names[@]}" -eq 0 ]; then
    log "no listening ports to tunnel"
    return 0
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
          log "WARN: tunnel ${name} applied but not active — see ${logfile}"
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

    # start failed or stuck — recreate (common after Sealos billing reclaim)
    log "WARN: start ${name} failed; recreating (cleanup+apply)"
    if echo "$start_out" | grep -qi 'Unauthorized\|re-login\|permission'; then
      log "NOTE: Unauthorized on ${name} — often stale remote after billing reclaim; recreating, not aborting batch"
    fi
    if recreate_project_tunnel "$cmd" "$name" "$port" "$logfile"; then
      if wait_tunnel_active "$name" 120; then
        log "tunnel ${name} active"
        ok=$((ok + 1))
      else
        log "WARN: tunnel ${name} still not active — see ${logfile}"
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
  [ "$ok" -gt 0 ]
}
