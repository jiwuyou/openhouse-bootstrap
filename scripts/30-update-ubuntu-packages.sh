#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[OpenHouse] %s\n' "$*"
}

run_logged() {
  log "+ $*"
  "$@"
}

if ! command -v proot-distro >/dev/null 2>&1 || ! proot-distro login ubuntu -- true >/dev/null 2>&1; then
  log "Ubuntu 不可用，请先运行：bash bootstrap.sh ubuntu"
  exit 2
fi

log "正在 Ubuntu 内更新 apt 索引。"
run_logged proot-distro login ubuntu -- bash -lc 'apt update'

log "正在 Ubuntu 内安装基础依赖。"
run_logged proot-distro login ubuntu -- bash -lc 'DEBIAN_FRONTEND=noninteractive apt install -y curl ca-certificates git procps ripgrep unzip'

log "Ubuntu 软件包阶段完成。"
