#!/bin/bash
# Minimal Android TV build - disable fat LTO to avoid OOM
set -e
CARGO_BUILD_JOBS=1 \
cargo build \
  --target armv7-unknown-linux-gnueabihf \
  --release \
  --no-default-features \
  --features "agent-runtime,default-channels" \
  -Z "build-std=std,panic_abort" \
  2>&1