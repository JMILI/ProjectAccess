#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "[build] cargo fmt check skipped, building..."
cargo build --release
echo "[build] done: target/release/ProjectAccess"
