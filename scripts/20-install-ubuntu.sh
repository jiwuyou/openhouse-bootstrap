#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[OpenHouse] %s\n' "$*"
}

run_logged() {
  log "+ $*"
  "$@"
}

if ! command -v proot-distro >/dev/null 2>&1; then
  log "缺少 proot-distro，请先运行：bash bootstrap.sh prepare"
  exit 2
fi

if proot-distro login ubuntu -- true >/dev/null 2>&1; then
  log "Ubuntu 已安装。"
  exit 0
fi

log "正在安装 Ubuntu rootfs。"
run_logged proot-distro install ubuntu

if proot-distro login ubuntu -- true >/dev/null 2>&1; then
  log "Ubuntu 安装完成。"
else
  log "Ubuntu 安装后未生成可用 rootfs。"
  exit 1
fi
