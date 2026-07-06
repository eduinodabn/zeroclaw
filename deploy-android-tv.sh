#!/bin/bash
# deploy-android-tv.sh — Build and deploy ZeroClaw to Android TV (ARM32v7)
#
# Android TV 14 with ARM32v7 architecture requires building from source.
# This script provides two deployment methods:
#
# Method 1: Termux on-device build (recommended for Android TV)
# Method 2: Cross-compile with Termux packages (requires Android NDK)
#
# Usage:
#   ./deploy-android-tv.sh --method termux
#   ./deploy-android-tv.sh --method cross-compile
#   ./deploy-android-tv.sh --help
#

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info() { echo -e "${BLUE}→${RESET} ${BOLD}$*${RESET}"; }
warn() { echo -e "${YELLOW}!${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }

show_help() {
  cat << EOF
ZeroClaw Android TV Deployment Script

TARGET: ARM32v7 Android TV 14

OPTIONS:
  --method <method>    Choose deployment method:
                       - termux: Build directly on Android TV via Termux
                       - cross-compile: Cross-compile on host machine (requires NDK)
  
  --help               Show this help message

REQUIREMENTS:
  Method 1 (Termux - recommended):
    - Android TV with Termux installed
    - 2GB+ RAM recommended
    - Storage permission granted to Termux
    
  Method 2 (Cross-compile):
    - Android NDK r25+ installed
    - ANDROID_NDK_HOME environment variable set
    - armv7-linux-androideabi Rust target

EXAMPLES:
  # Deploy via Termux (recommended)
  ./deploy-android-tv.sh --method termux
  
  # Cross-compile for Android (requires NDK)
  export ANDROID_NDK_HOME=/opt/android-ndk-r25c
  ./deploy-android-tv.sh --method cross-compile

EOF
  exit 0
}

METHOD="${1:-}"
if [[ "$METHOD" == "--help" ]]; then
  show_help
fi

if [[ -z "$METHOD" ]]; then
  warn "No method specified. Use --method termux or --method cross-compile"
  show_help
fi

case "$METHOD" in
  --method)
    DEPLOY_METHOD="${2:-termux}"
    ;;
  *)
    warn "Unknown option: $METHOD"
    show_help
    ;;
esac

info "ZeroClaw Android TV Deployment — ARM32v7"
echo ""

# ── Method 1: Termux on-device build ─────────────────────────────
deploy_via_termux() {
  info "Method 1: Building on Android TV via Termux"
  echo ""
  cat << 'EOF'
STEP 1: Install Termux on Android TV
─────────────────────────────────────
  1. Download Termux from F-Droid (NOT Play Store):
     https://f-droid.org/packages/com.termux/
  
  2. Install on Android TV:
     - Transfer APK to Android TV via USB/network
     - Use Android TV's file manager to install
     - Grant storage permission: termux-setup-storage

STEP 2: Build ZeroClaw in Termux
─────────────────────────────────
  Open Termux on Android TV and run:

  # Update packages
  pkg update && pkg upgrade -y
  
  # Install build dependencies
  pkg install -y rust git cmake clang python
  
  # Clone repository
  git clone https://github.com/zeroclaw-labs/zeroclaw.git
  cd zeroclaw
  
  # Build for ARM32v7
  cargo build --release --no-default-features \
    --features "agent-runtime,default-channels"
  
  # Install binary
  cp target/release/zeroclaw \$PREFIX/bin/
  
  # Run quickstart
  zeroclaw quickstart

STEP 3: Run ZeroClaw
───────────────────
  # Start agent
  zeroclaw agent -a default
  
  # Or run as background service
  zeroclaw daemon

OPTIMIZATION NOTES:
──────────────────
  - Build time: 30-60 minutes on Android TV
  - Use --no-default-features to reduce build time
  - Add specific channels as needed: --features "channel-telegram,channel-discord"
  - Monitor memory: Android TV may have limited RAM

EOF
}

# ── Method 2: Cross-compile with NDK ───────────────────────────────
deploy_via_cross_compile() {
  info "Method 2: Cross-compiling for Android TV"
  echo ""
  
  # Check for Android NDK
  if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
    warn "ANDROID_NDK_HOME not set"
    cat << 'EOF'
Install Android NDK and set environment variable:

  # Download NDK (r25c recommended for Termux compatibility)
  wget https://dl.google.com/android/repository/android-ndk-r25c-linux.zip
  unzip android-ndk-r25c-linux.zip -d /opt
  export ANDROID_NDK_HOME=/opt/android-ndk-r25c
  
  # Add to PATH
  export PATH=\$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:\$PATH

EOF
    exit 1
  fi
  
  # Check for required tools
  NDK_CLANG="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi21-clang"
  if [[ ! -f "$NDK_CLANG" ]]; 
    then
    warn "NDK clang not found at: $NDK_CLANG"
    exit 1
  fi
  
  success "NDK found: ${ANDROID_NDK_HOME}"
  
  # Add Rust target
  info "Adding Rust target: armv7-linux-androideabi"
  rustup target add armv7-linux-androideabi 2>/dev/null || true
  
  # Build
  info "Building ZeroClaw for Android ARM32v7..."
  TARGET="armv7-linux-androideabi"
  
  cargo build \
    --target "${TARGET}" \
    --release \
    --no-default-features \
    --features "agent-runtime,default-channels"
  
  BINARY="target/${TARGET}/release/zeroclaw"
  if [[ -f "$BINARY" ]]; then
    success "Build complete: ${BINARY}"
    ls -lh "${BINARY}"
    
    cat << EOF

DEPLOYMENT OPTIONS:
───────────────────

Option A: Transfer via USB/network
  1. Copy binary to Android TV storage
  2. Install Termux on Android TV
  3. In Termux: cp /path/to/zeroclaw \$PREFIX/bin/
  4. zeroclaw quickstart

Option B: Deploy via ADB
  adb push ${BINARY} /data/local/tmp/
  adb shell chmod +x /data/local/tmp/zeroclaw
  adb shell /data/local/tmp/zeroclaw --version

Option C: Package for Termux
  tar czf zeroclaw-armv7-linux-androideabi.tar.gz -C target/${TARGET}/release zeroclaw
  # Transfer and extract in Termux

EOF
  else
    warn "Build failed - binary not found"
    exit 1
  fi
}

# ── Execute deployment method ────────────────────────────────────────
case "$DEPLOY_METHOD" in
  termux)
    deploy_via_termux
    ;;
  cross-compile)
    deploy_via_cross_compile
    ;;
  *)
    warn "Unknown method: $DEPLOY_METHOD"
    show_help
    ;;
esac

echo ""
info "Next steps:"
echo "  1. Install Termux on Android TV from F-Droid"
echo "  2. Follow the deployment instructions above"
echo "  3. Run 'zeroclaw quickstart' to configure"
echo ""