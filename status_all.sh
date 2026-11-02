#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/projects_lib.sh
source "${SCRIPT_DIR}/scripts/projects_lib.sh"

echo "ProjectAccess managed services"
echo "run_dir: ${RUN_DIR}"
echo "----------------------------------------"
print_port_status "ProjectAccess hub" 18200 "http://127.0.0.1:18200/"
print_port_status "WestChina UI" 5000 "http://127.0.0.1:5000/main/"
print_port_status "encoding_practice" 3000 "http://127.0.0.1:3000/"
print_port_status "offer" 4000 "http://127.0.0.1:4000/"
print_port_status "cPlusBook" 4001 "http://127.0.0.1:4001/"
print_port_status "fengsheng UI" 5173 "http://127.0.0.1:5173/"
print_port_status "fengsheng-dev UI" 5178 "http://127.0.0.1:5178/"
print_port_status "rust-thread UI" 5180 "http://127.0.0.1:5180/"
print_port_status "rust-compile UI" 5175 "http://127.0.0.1:5175/"

if port_listening 18080; then
  print_port_status "rust-compile API" 18080 "http://127.0.0.1:18080/"
elif port_listening 8080; then
  print_port_status "rust-compile API" 8080 "http://127.0.0.1:8080/"
else
  printf "  %-18s %-11s DOWN\n" "rust-compile API" "(18080/8080)"
fi

echo "----------------------------------------"
SEALTUN_BIN=""
if command -v sealtun >/dev/null 2>&1; then
  SEALTUN_BIN="sealtun"
elif command -v npx >/dev/null 2>&1; then
  SEALTUN_BIN="npx sealtun"
fi

if [ -n "$SEALTUN_BIN" ]; then
  echo "Active sealtun tunnels (named):"
  LIST_OUT=""
  # shellcheck disable=SC2086
  if LIST_OUT="$(timeout 12 $SEALTUN_BIN list 2>/dev/null)"; then
    MATCHED="$(echo "$LIST_OUT" | grep -E 'NAME|TUNNEL ID|project-access|wisdom-ui|westchina|encoding|offer-ui|cplusbook|rust-compile|fengsheng|rust-thread' || true)"
    if [ -n "$MATCHED" ]; then
      echo "$MATCHED" | sed 's/^/  /'
    else
      echo "  (none matching managed projects — run start_all or: bash tunnel.sh apply)"
    fi
  else
    echo "  (sealtun list timeout or unavailable — check: sealtun status / login gzg)"
  fi
fi
