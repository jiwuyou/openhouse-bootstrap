#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[OpenHouse] %s\n' "$*"
}

if [ -z "${PREFIX:-}" ] || [ ! -d "${PREFIX:-}/bin" ] || [ ! -d "/data/data/com.termux/files" ]; then
  log "请在官方 Termux 内运行。"
  exit 1
fi

log "Termux PREFIX: $PREFIX"
log "HOME: $HOME"

if [ ! -d "$HOME/storage" ]; then
  log "提示：如需访问共享存储，请手动运行 termux-setup-storage 并在系统弹窗中授权。"
else
  log "共享存储入口已存在：$HOME/storage"
fi

if command -v termux-info >/dev/null 2>&1; then
  termux-info || true
else
  log "termux-info 不存在，稍后准备阶段会安装基础包。"
fi

log "环境检查完成。"
