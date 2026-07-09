#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-18200}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$SCRIPT_DIR"
echo "[start] build release binary..."
cargo build --release
echo "[start] running on :$PORT"
PORT="$PORT" ./target/release/ProjectAccess
