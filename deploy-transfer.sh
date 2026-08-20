#!/bin/bash
# ZeroClaw Android TV 部署文件传输工具
# 支持: HTTP下载 / ADB推送 / Termux SSH SCP

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

PACKAGE="zeroclaw-arm32v7-android-tv.tar.gz"
PACKAGE_PATH="/workspace/install/$PACKAGE"
HTTP_PORT=8000

info() { echo -e "${BLUE}→${RESET} ${BOLD}$*${RESET}"; }
ok()   { echo -e "${GREEN}✓${RESET} $*"; }
warn() { echo -e "${YELLOW}!${RESET} $*"; }

show_help() {
  cat << EOF
ZeroClaw Android TV 安装包传输工具

用法:
  $0 <方法> [选项]

传输方法:
  http              启动HTTP服务器，Android TV端下载
  adb <设备IP>      通过ADB push到设备 (需安装adb)
  scp <IP:端口>     通过SSH(SCP)上传到Termux (需Termux开启sshd)

示例:
  $0 http                            # 启动HTTP服务器
  $0 adb 192.168.1.100               # 推送到ADB网络设备
  $0 scp 192.168.1.100:8022          # SCP到Termux (用户u0_axxx)
EOF
}

# ─────────────────────────────────────────────
# 方法1: HTTP文件服务器
# ─────────────────────────────────────────────
start_http_server() {
  info "启动HTTP文件服务器"
  
  if [[ ! -f "$PACKAGE_PATH" ]]; then
    warn "安装包不存在: $PACKAGE_PATH"
    exit 1
  fi
  
  HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [[ -z "$HOST_IP" ]]; then
    HOST_IP="<本机局域网IP>"
  fi
  
  # 创建包含安装说明的index.html
  mkdir -p /workspace/install/http-root
  cp "$PACKAGE_PATH" /workspace/install/http-root/
  cp /workspace/ANDROID-TV-DEPLOYMENT.md /workspace/install/http-root/ 2>/dev/null || true
  
  cat > /workspace/install/http-root/index.html << HTML
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>ZeroClaw Android TV 安装包下载</title>
<style>
body{font-family:system-ui,-apple-system,sans-serif;max-width:720px;margin:40px auto;padding:20px;background:#111;color:#eee}
a{color:#4ea1ff}
.code{background:#1e1e1e;padding:16px;border-radius:8px;overflow-x:auto;word-break:break-all}
.pkg{background:#2d5016;padding:20px;border-radius:12px;text-align:center;margin:24px 0}
.big{font-size:1.5em;font-weight:700;color:#9aff7a}
</style></head><body>
<h1>🦀 ZeroClaw ARM32v7 Android TV 安装包</h1>
<div class="pkg">
<div><a href="$PACKAGE" style="color:#fff;font-size:1.8em;font-weight:800">⬇ 点击下载 $PACKAGE</a></div>
<div style="margin-top:12px;color:#cde;font-size:.95em">41 MB · 版本 0.8.2 · armv7l</div>
</div>
<h2>Termux 一键下载安装命令</h2>
<div class="code"><pre>
# 在Termux中粘贴以下命令 (二选一)

# 选项A: 从HTTP服务器下载
curl -L -O http://${HOST_IP}:${HTTP_PORT}/${PACKAGE} && \
tar xzf ${PACKAGE} && cd zeroclaw && ./install.sh && zeroclaw quickstart

# 选项B: wget下载
wget http://${HOST_IP}:${HTTP_PORT}/${PACKAGE} && \
tar xzf ${PACKAGE} && cd zeroclaw && ./install.sh && zeroclaw quickstart
</pre></div>
<h2>文件校验</h2>
<div class="code"><pre>
# SHA256: $(sha256sum "$PACKAGE_PATH" | awk '{print $1}')
# 下载后验证:
sha256sum $PACKAGE</pre></div>
<h2>安装步骤</h2>
<ol>
<li>下载完成后: <code>tar xzf $PACKAGE</code></li>
<li>进入目录: <code>cd zeroclaw</code></li>
<li>安装: <code>./install.sh</code></li>
<li>配置: <code>zeroclaw quickstart</code></li>
<li>启动: <code>zeroclaw agent -a default</code></li>
</ol>
</body></html>
HTML
  
  ok "下载页面准备完成"
  echo ""
  info "下载地址:"
  echo "  Android TV浏览器/Termux: http://${HOST_IP}:${HTTP_PORT}/"
  echo "  直接下载链接:    http://${HOST_IP}:${HTTP_PORT}/${PACKAGE}"
  echo ""
  info "Termux下载安装命令 (复制粘贴到Termux):"
  echo -e "${GREEN}  curl -L -O http://${HOST_IP}:${HTTP_PORT}/${PACKAGE} && tar xzf ${PACKAGE} && cd zeroclaw && ./install.sh && zeroclaw quickstart${RESET}"
  echo ""
  warn "请确保本机和Android TV连接到 <同一局域网>"
  warn "按 Ctrl+C 停止服务器"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # 启动服务器
  cd /workspace/install/http-root
  python3 -m http.server ${HTTP_PORT} --bind 0.0.0.0
}

# ─────────────────────────────────────────────
# 方法2: ADB传输
# ─────────────────────────────────────────────
transfer_via_adb() {
  local DEVICE_IP="$1"
  [[ -z "$DEVICE_IP" ]] && { warn "请提供设备IP，如: $0 adb 192.168.1.100"; exit 1; }
  
  info "通过ADB传输到: $DEVICE_IP"
  if ! command -v adb &>/dev/null; then
    warn "ADB未安装，尝试通过apt安装"
    apt-get update && apt-get install -y adb
  fi
  
  info "连接ADB设备..."
  adb connect "${DEVICE_IP}:5555" 2>&1 || { warn "连接失败。请确认Android TV已开启USB调试和无线调试。"; exit 1; }
  
  ok "ADB连接成功: $DEVICE_IP"
  info "推送安装包..."
  adb -s "${DEVICE_IP}:5555" push "$PACKAGE_PATH" /data/local/tmp/
  
  info "在设备上执行安装..."
  adb -s "${DEVICE_IP}:5555" shell << 'EOF'
cd /data/local/tmp && \
test -f zeroclaw-arm32v7-android-tv.tar.gz && \
tar xzf zeroclaw-arm32v7-android-tv.tar.gz -C /data/local/tmp/ && \
echo "解压完成" && ls -la /data/local/tmp/zeroclaw/
EOF
  
  echo ""
  ok "传输完成！"
  echo "后续操作:"
  echo "  1. adb shell (进入设备shell)"
  echo "  2. 如果已安装Termux: adb push /data/local/tmp/zeroclaw /sdcard/"
  echo "  3. Termux中: cp /sdcard/zeroclaw/zeroclaw $PREFIX/bin/ && chmod +x $PREFIX/bin/zeroclaw"
}

# ─────────────────────────────────────────────
# 方法3: SCP传输到Termux SSH
# ─────────────────────────────────────────────
transfer_via_scp() {
  local TARGET="$1"
  [[ -z "$TARGET" ]] && { warn "请提供Termux SSH地址，如: 192.168.1.100:8022"; exit 1; }
  local IP="${TARGET%%:*}"
  local PORT="${TARGET##*:}"
  [[ "$PORT" == "$IP" ]] && PORT=8022  # Termux默认SSH端口
  
  info "通过SCP传输到 Termux SSH: $IP:$PORT"
  echo ""
  info "请先在Android TV的Termux中启用SSH:"
  echo "  pkg install -y openssh"
  echo "  sshd -p $PORT  # 启动SSH服务"
  echo "  whoami          # 查看用户名 (通常是u0_axxx)"
  echo "  passwd          # 设置密码"
  echo ""
  read -rp "请输入Termux用户名: " SSH_USER
  [[ -z "$SSH_USER" ]] && SSH_USER="$(whoami 2>/dev/null || echo u0_a200)"
  
  info "正在推送: $USER@$IP:$PORT:/data/data/com.termux/files/home/"
  scp -P "$PORT" "$PACKAGE_PATH" "${SSH_USER}@${IP}:/data/data/com.termux/files/home/"
  
  echo ""
  ok "传输完成！"
  info "在Termux中执行安装:"
  echo "  cd ~ && tar xzf $PACKAGE && cd zeroclaw && ./install.sh && zeroclaw quickstart"
}

# ─────────────────────────────────────────────
# 入口
# ─────────────────────────────────────────────
METHOD="${1:-http}"
case "$METHOD" in
  -h|--help|help) show_help;;
  http)    start_http_server;;
  adb)     transfer_via_adb "${2:-}";;
  scp)     transfer_via_scp "${2:-}";;
  *)       warn "未知方法: $METHOD"; show_help; exit 1;;
esac