#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[OpenHouse] %s\n' "$*"
}

run_logged() {
  log "+ $*"
  "$@"
}

TERMUX_HOME="${HOME:-/data/data/com.termux/files/home}"
DOC_DIR="$TERMUX_HOME/product-docs"
WORKSPACE_DIR="$TERMUX_HOME/workspace"
TERMUX_CONFIG_DIR="$TERMUX_HOME/.termux"
TERMUX_PROPERTIES_FILE="$TERMUX_CONFIG_DIR/termux.properties"

log "正在确保基础目录存在。"
mkdir -p "$DOC_DIR" "$WORKSPACE_DIR" "$TERMUX_CONFIG_DIR"
chmod 700 "$DOC_DIR" "$WORKSPACE_DIR" "$TERMUX_CONFIG_DIR" || true

log "正在启用 allow-external-apps。"
touch "$TERMUX_PROPERTIES_FILE"
if grep -q '^[[:space:]]*allow-external-apps' "$TERMUX_PROPERTIES_FILE"; then
  sed -i 's/^[[:space:]]*allow-external-apps[[:space:]]*=.*/allow-external-apps = true/' "$TERMUX_PROPERTIES_FILE"
else
  printf '\nallow-external-apps = true\n' >> "$TERMUX_PROPERTIES_FILE"
fi

log "正在安装 Termux 基础包。"
run_logged pkg update -y
run_logged pkg install -y proot-distro curl libcurl libngtcp2 libnghttp2 openssl ca-certificates git

if ! curl --version >/dev/null 2>&1; then
  log "curl 仍不可用，尝试完整升级 Termux 依赖。"
  run_logged pkg upgrade -y
  run_logged pkg install -y curl libcurl libngtcp2 libnghttp2 openssl ca-certificates
fi

if ! curl --version >/dev/null 2>&1; then
  log "curl 修复失败，请手动执行：pkg upgrade -y && pkg install -y curl libcurl libngtcp2 libnghttp2 openssl ca-certificates"
  exit 1
fi

cat > "$DOC_DIR/README.md" <<'EOF'
# Product Docs

This directory is visible to OpenCode. Put stable product notes here.
EOF

cat > "$DOC_DIR/USER_GUIDE.md" <<'EOF'
# User Guide

1. Open the browser page served by OpenCode.
2. Ask the agent to read AI_GUIDE.md before starting work.
3. Keep your projects under ~/workspace.
EOF

cat > "$DOC_DIR/AI_GUIDE.md" <<'EOF'
# AI Guide

You are operating inside a local Termux + Ubuntu proot workspace.

Rules:
- Read README.md and this AI_GUIDE.md before making changes.
- Treat ~/workspace as the writable area for user projects.
- Keep generated artifacts organized and explain what was changed.
- Do not write provider API keys into tracked files or shared docs.
EOF

log "文档路径：$DOC_DIR"
log "工作区路径：$WORKSPACE_DIR"
log "Termux 配置：$TERMUX_PROPERTIES_FILE"
log "Termux 准备阶段完成。"
