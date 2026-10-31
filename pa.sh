#!/usr/bin/env bash
# pa.sh — ProjectAccess 一键编排入口（本地服务 + Sealtun 隧道）
# 用法:
#   bash pa.sh up [all|light|PROJECT...]     启动本地 + 隧道（默认并行起隧道）
#   bash pa.sh up-local [PROJECT...]         仅启动本地（等价 SKIP_TUNNEL=1）
#   bash pa.sh down [all|PROJECT...]         停止本地 + 隧道
#   bash pa.sh down-local [PROJECT...]       只停本地，保留隧道
#   bash pa.sh restart [PROJECT...]          down 后 up
#   bash pa.sh status                        端口 + 隧道状态（= status_all.sh）
#   bash pa.sh url                           打印全部访问链接（本地 + 公网）
#   bash pa.sh tunnel [up|down|status]       只操作隧道
#   bash pa.sh logs PROJECT                  跟随某个项目日志
#   bash pa.sh doctor                        依赖体检（jdk/node/rust/sealtun/docker）
#
# 项目名: hub wisdom westchina encoding cplusbook offer rust-compile fengsheng rust-thread
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
source "${DIR}/scripts/projects_lib.sh"

# 端口/隧道名映射（与 scripts/projects_lib.sh 的 tunnel_spec_for_project 保持一致）
port_of() {
  case "$1" in
    hub) echo 18200 ;;
    wisdom) echo 9527 ;;
    westchina) echo 5000 ;;
    encoding) echo 3000 ;;
    offer) echo 4000 ;;
    cplusbook) echo 4001 ;;
    rust-compile) echo 5175 ;;
    fengsheng) echo 5173 ;;
    rust-thread) echo 5180 ;;
    *) echo "" ;;
  esac
}

tunnel_of() {
  local spec
  spec="$(tunnel_spec_for_project "$1" 2>/dev/null || true)"
  [ -n "$spec" ] && echo "${spec%%:*}"
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  up)
    if [ "$#" -eq 0 ]; then bash start_all.sh all; else bash start_all.sh "$@"; fi
    ;;
  up-local)
    if [ "$#" -eq 0 ]; then SKIP_TUNNEL=1 bash start_all.sh all; else SKIP_TUNNEL=1 bash start_all.sh "$@"; fi
    ;;
  down)
    if [ "$#" -eq 0 ]; then bash stop_all.sh all; else bash stop_all.sh "$@"; fi
    ;;
  down-local)
    if [ "$#" -eq 0 ]; then KEEP_TUNNEL=1 bash stop_all.sh all; else KEEP_TUNNEL=1 bash stop_all.sh "$@"; fi
    ;;
  restart)
    if [ "$#" -eq 0 ]; then bash stop_all.sh all; else bash stop_all.sh "$@"; fi
    if [ "$#" -eq 0 ]; then bash start_all.sh all; else bash start_all.sh "$@"; fi
    ;;
  status)
    bash status_all.sh
    ;;
  url)
    printf '%-14s %-7s %-24s %s\n' PROJECT PORT LOCAL TUNNEL
    for p in hub wisdom westchina encoding offer cplusbook rust-compile fengsheng rust-thread; do
      port="$(port_of "$p")"
      tun="$(tunnel_of "$p")"
      if [ -n "$tun" ]; then
        url="$(tunnel_public_url "$tun" 2>/dev/null || echo "-")"
      else
        url="-"
      fi
      printf '%-14s %-7s %-24s %s\n' "$p" "$port" "http://127.0.0.1:${port}/" "$url"
    done
    ;;
  tunnel)
    sub="${1:-status}"
    shift || true
    case "$sub" in
      up) if [ "$#" -eq 0 ]; then bash tunnel.sh apply all; else bash tunnel.sh apply "$@"; fi ;;
      down) if [ "$#" -eq 0 ]; then bash tunnel.sh stop "${ALL_PROJECTS[@]}"; else bash tunnel.sh stop "$@"; fi ;;
      status) bash tunnel.sh status ;;
      *) echo "usage: bash pa.sh tunnel [up|down|status]" >&2; exit 2 ;;
    esac
    ;;
  logs)
    p="${1:-}"
    [ -z "$p" ] && { echo "usage: bash pa.sh logs PROJECT" >&2; exit 2; }
    log="${RUN_DIR}/${p}.log"
    [ -f "$log" ] || { echo "no log: $log (available: $(ls "${RUN_DIR}"/*.log 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' '))" >&2; exit 1; }
    tail -f "$log"
    ;;
  doctor)
    rc=0
    check() { printf '  %-22s %s\n' "$1" "$2"; }
    echo "ProjectAccess doctor"
    command -v node >/dev/null && check node "$(node -v)" || { check node MISSING; rc=1; }
    command -v npm >/dev/null && check npm "$(npm -v)" || { check npm MISSING; rc=1; }
    if command -v cargo >/dev/null; then check cargo "$(cargo --version 2>/dev/null | cut -d' ' -f2)"; else check cargo MISSING; rc=1; fi
    if command -v java >/dev/null; then check java "$(java -version 2>&1 | head -1)"; else check java "MISSING (westChina 需要 JDK8)"; fi
    command -v mvn >/dev/null && check mvn "$(mvn -v 2>/dev/null | head -1)" || check mvn "missing (WestChina 后端构建需要)"
    if command -v sealtun >/dev/null; then
      check sealtun "$(sealtun --version 2>&1 | head -1)"
      sealtun status 2>/dev/null | grep -E 'Logged in|Workspace' | sed 's/^/    /'
    else
      check sealtun MISSING
      rc=1
    fi
    command -v docker >/dev/null && check docker "$(docker --version)" || check docker "missing (wisdom/WestChina 中间件需要)"
    echo "  -- ports --"
    for p in hub wisdom westchina encoding offer cplusbook rust-compile fengsheng rust-thread; do
      port="$(port_of "$p")"
      if port_listening "$port"; then check "$p:$port" UP; else check "$p:$port" down; fi
    done
    exit "$rc"
    ;;
  help|-h|--help|"")
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "unknown command: $cmd (try: bash pa.sh help)" >&2
    exit 2
    ;;
esac
