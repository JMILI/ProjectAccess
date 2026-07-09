#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v sealtun >/dev/null 2>&1; then
  echo "[error] sealtun 未安装"
  exit 1
fi

ACTION="${1:-status}"
case "$ACTION" in
  apply)
    sealtun apply -f sealtun.yaml
    ;;
  status)
    sealtun list
    ;;
  delete)
    ID="$(sealtun list 2>/dev/null | awk '/project-hub-rust/ {print $1; exit}')"
    if [ -n "$ID" ]; then
      sealtun stop "$ID"
    else
      echo "project-hub-rust tunnel not found"
    fi
    ;;
  *)
    echo "Usage: bash tunnel.sh [apply|status|delete]"
    exit 1
    ;;
esac
