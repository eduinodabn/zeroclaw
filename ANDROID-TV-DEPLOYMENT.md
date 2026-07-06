# ZeroClaw Android TV Deployment Guide

ARM32v7 / Android TV 14 deployment instructions.

## Target Architecture

**ARM32v7 (armv7l)** — 32-bit ARM devices including:
- Android TV boxes with 32-bit processors
- Older Android TV models
- Android 14 devices without 64-bit support

Check your device architecture:
```sh
# In Termux or Android shell
uname -m
# Output: armv7l or armv8l = 32-bit ARM
# Output: aarch64 = 64-bit ARM (use aarch64-linux-android prebuilt)
```

## Deployment Methods

### Method 1: Termux On-Device Build (Recommended)

Best for Android TV as it ensures compatibility with Termux environment.

#### Step 1: Install Termux

1. **Download Termux from F-Droid** (NOT Play Store - outdated version)
   - URL: https://f-droid.org/packages/com.termux/
   - Transfer APK to Android TV via USB drive or network share
   
2. **Install on Android TV**
   - Use Android TV's file manager or package installer
   - Grant all requested permissions
   
3. **Setup storage access**
   ```sh
   termux-setup-storage
   # Grant permission when prompted
   ```

#### Step 2: Build in Termux

Open Termux on Android TV:

```sh
# Update packages
pkg update && pkg upgrade -y

# Install build dependencies (minimal set)
pkg install -y rust git cmake clang python make

# Clone ZeroClaw
git clone https://github.com/zeroclaw-labs/zeroclaw.git
cd zeroclaw

# Build with minimal features (fastest build)
cargo build --release --no-default-features \
  --features "agent-runtime"

# Or with default channels (longer build)
cargo build --release

# Install binary
cp target/release/zeroclaw $PREFIX/bin/
chmod +x $PREFIX/bin/zeroclaw

# Verify
zeroclaw --version
```

#### Step 3: Configure and Run

```sh
# Initial setup
zeroclaw quickstart

# Run agent
zeroclaw agent -a default

# Or run daemon mode
zeroclaw daemon
```

#### Build Time Estimates

| Features | Build Time | Binary Size |
|----------|------------|-------------|
| `--no-default-features` + `agent-runtime` | 30-45 min | ~15 MB |
| Default features | 45-60 min | ~25 MB |
| Full features (`channels-full`) | 60-90 min | ~35 MB |

### Method 2: Cross-Compile from Host Machine

Cross-compile on your development machine, deploy to Android TV.

#### Prerequisites on Host

1. **Install Android NDK r25c** (recommended for Termux compatibility)
   ```sh
   # Linux
   wget https://dl.google.com/android/repository/android-ndk-r25c-linux.zip
   unzip android-ndk-r25c-linux.zip -d /opt
   export ANDROID_NDK_HOME=/opt/android-ndk-r25c
   export PATH=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH
   ```

2. **Add Rust target**
   ```sh
   rustup target add armv7-linux-androideabi
   ```

3. **Configure cargo** (already configured in `.cargo/config.toml`)
   ```toml
   [target.armv7-linux-androideabi]
   linker = "armv7a-linux-androideabi21-clang"
   ```

#### Build for Android

```sh
# Clone if not already
git clone https://github.com/zeroclaw-labs/zeroclaw.git
cd zeroclaw

# Build
export ANDROID_NDK_HOME=/opt/android-ndk-r25c
cargo build --release --target armv7-linux-androideabi \
  --no-default-features --features "agent-runtime"

# Binary location
ls -lh target/armv7-linux-androideabi/release/zeroclaw
```

#### Deploy to Android TV

**Option A: USB Transfer**
```sh
# On host: copy to USB drive
cp target/armv7-linux-androideabi/release/zeroclaw /media/usb/

# On Android TV: 
# - Insert USB drive
# - In Termux: cp /storage/USB/zeroclaw $PREFIX/bin/
# - chmod +x $PREFIX/bin/zeroclaw
```

**Option B: ADB Deploy**
```sh
# Push via ADB
adb push target/armv7-linux-androideabi/release/zeroclaw /data/local/tmp/
adb shell chmod +x /data/local/tmp/zeroclaw

# Test
adb shell /data/local/tmp/zeroclaw --version

# Install in Termux (requires root or Termux with proper permissions)
adb shell cp /data/local/tmp/zeroclaw /data/data/com.termux/files/usr/bin/
```

**Option C: Network Transfer**
```sh
# Package
tar czf zeroclaw-armv7.tar.gz -C target/armv7-linux-androideabi/release zeroclaw

# Transfer via HTTP/FTP/SMB to Android TV
# In Termux: wget/curl to download and extract
wget http://your-server/zeroclaw-armv7.tar.gz
tar xzf zeroclaw-armv7.tar.gz
cp zeroclaw $PREFIX/bin/
```

### Method 3: Use Deployment Script

Run the provided deployment script:

```sh
./deploy-android-tv.sh --method termux       # Shows Termux build instructions
./deploy-android-tv.sh --method cross-compile # Attempts cross-compile
```

## Android TV Specific Considerations

### Storage Permissions

Termux requires storage permission to access files:
```sh
termux-setup-storage
# This creates ~/storage directory with access to shared storage
```

### Performance Optimization

Android TV boxes often have limited RAM (1-2GB). Optimize for low-memory:

1. **Use minimal feature set**
   ```sh
   cargo build --release --no-default-features --features "agent-runtime"
   ```

2. **Reduce build parallelism**
   ```sh
   # Set lower job count to avoid OOM during build
   CARGO_BUILD_JOBS=2 cargo build --release
   ```

3. **Use prebuilt if available** (64-bit devices only)
   - 32-bit devices must build from source
   - No prebuilt binary for armv7-linux-androideabi

### Power Management

Android TV may sleep/hibernate. To keep ZeroClaw running:

```sh
# In Termux
# Keep Termux session active
termux-wake-lock

# Run daemon mode
zeroclaw daemon
```

### Network Configuration

Android TV may restrict network access:

```sh
# Check network
ping -c 3 google.com

# If using gateway feature
zeroclaw gateway --bind 0.0.0.0:8080

# Android TV firewall may block ports
# Use port 8080 (usually allowed) or configure TV settings
```

## Troubleshooting

### Build Fails with "Out of Memory"

Android TV with 1GB RAM may fail during compilation:

```sh
# Solution: Reduce parallelism
CARGO_BUILD_JOBS=1 cargo build --release

# Or build in stages (incremental)
cargo build --release -p zeroclaw-config
cargo build --release -p zeroclaw-api
cargo build --release  # Continue remaining
```

### "Permission Denied" Errors

```sh
# In Termux
chmod +x $PREFIX/bin/zeroclaw

# Check Termux permissions in Android TV settings
# Grant "Allow from this source" for Termux
```

### Binary Not Found

```sh
# Verify architecture match
uname -m  # Should show armv7l or armv8l

# Check binary type
file zeroclaw
# Should show: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV)
```

### Network Issues

```sh
# Test connectivity
curl -I https://api.anthropic.com

# If blocked, check Android TV network settings
# May need to disable "Network restriction" in TV settings
```

## Feature Selection

Minimal recommended feature set for Android TV:

```toml
# ~/.zeroclaw/config.toml minimal example
[agents.default]
model_provider = "anthropic.default"
autonomy = "supervised"

[providers.models.anthropic.default]
api_key = "sk-ant-..."
model = "claude-3-5-sonnet-20241022"
```

Build with:
```sh
cargo build --release --no-default-features \
  --features "agent-runtime,channel-telegram"
  # Add only channels you need
```

## Quick Reference

| Command | Purpose |
|---------|---------|
| `uname -m` | Check device architecture |
| `pkg install rust git` | Install build tools |
| `cargo build --release` | Build ZeroClaw |
| `zeroclaw quickstart` | Initial configuration |
| `zeroclaw agent -a default` | Start agent |
| `zeroclaw daemon` | Run as service |
| `termux-setup-storage` | Grant storage permission |
| `termux-wake-lock` | Prevent Android sleep |

## Next Steps

After successful deployment:

1. **Configure provider** — Run `zeroclaw quickstart` or manually edit `~/.zeroclaw/config.toml`
2. **Test agent** — `zeroclaw agent -a default`
3. **Setup channels** — Add `[channels.telegram.bot1]` etc. as needed
4. **Enable daemon** — For persistent operation on Android TV

## Resources

- [Android Setup Guide](docs/book/src/hardware/android-setup.md)
- [Termux Wiki](https://wiki.termux.com/)
- [Android NDK Downloads](https://developer.android.com/ndk/downloads)
- [ZeroClaw Quickstart](docs/book/src/getting-started/quickstart.md)