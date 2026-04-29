#!/usr/bin/env bash
set -euo pipefail

OPENHOUSE_DIR="${OPENHOUSE_DIR:-$HOME/.openhouse-bootstrap}"
OPENHOUSE_RAW_BASE="${OPENHOUSE_RAW_BASE:-https://raw.githubusercontent.com/jiwuyou/openhouse-bootstrap/main}"
OPENHOUSE_PORT="${OPENHOUSE_PORT:-8765}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '[OpenHouse] %s\n' "$*"
}

die() {
  log "ERROR: $*" >&2
  exit 1
}

run_logged() {
  log "+ $*"
  "$@"
}

is_termux() {
  [ -n "${PREFIX:-}" ] && [ -d "${PREFIX:-}/bin" ] && [ -d "/data/data/com.termux/files" ]
}

ensure_termux() {
  is_termux || die "请在官方 Termux 内运行，不要在 Android adb shell 或普通 Linux 主机运行。"
}

ensure_local_layout() {
  mkdir -p "$OPENHOUSE_DIR/scripts" "$OPENHOUSE_DIR/skills" "$OPENHOUSE_DIR/docs"

  if [ -d "$SCRIPT_DIR/scripts" ]; then
    return 0
  fi

  ensure_termux_curl

  log "正在从 $OPENHOUSE_RAW_BASE 下载阶段脚本"
  for name in \
    00-check-termux.sh \
    10-prepare-termux.sh \
    20-install-ubuntu.sh \
    30-update-ubuntu-packages.sh \
    40-install-opencode.sh \
    42-install-codex.sh \
    44-install-claude-code.sh \
    50-install-ai-agents-skill.sh \
    60-start-opencode.sh \
    70-configure-entry.sh \
    80-openhouse-web.sh; do
    curl -fsSL "$OPENHOUSE_RAW_BASE/scripts/$name" -o "$OPENHOUSE_DIR/scripts/$name"
    chmod +x "$OPENHOUSE_DIR/scripts/$name"
  done

  mkdir -p \
    "$OPENHOUSE_DIR/skills/system-environment-description" \
    "$OPENHOUSE_DIR/skills/install-ai-agents"
  curl -fsSL "$OPENHOUSE_RAW_BASE/skills/system-environment-description/SKILL.md" \
    -o "$OPENHOUSE_DIR/skills/system-environment-description/SKILL.md"
  curl -fsSL "$OPENHOUSE_RAW_BASE/skills/install-ai-agents/SKILL.md" \
    -o "$OPENHOUSE_DIR/skills/install-ai-agents/SKILL.md"
}

ensure_termux_curl() {
  if command -v curl >/dev/null 2>&1 && curl --version >/dev/null 2>&1; then
    return 0
  fi

  is_termux || die "curl 不可用，且当前不是 Termux，无法自动修复。"
  command -v pkg >/dev/null 2>&1 || die "curl 不可用，且缺少 pkg，无法自动修复。"

  log "curl 不可用，正在修复 Termux 网络依赖。"
  run_logged pkg update -y || true
  run_logged pkg install -y curl libcurl libngtcp2 libnghttp2 openssl ca-certificates

  if ! curl --version >/dev/null 2>&1; then
    die "curl 修复失败，请先执行：pkg upgrade -y && pkg install -y curl libcurl libngtcp2 libnghttp2 openssl ca-certificates"
  fi
}

script_path() {
  local name="$1"
  if [ -f "$SCRIPT_DIR/scripts/$name" ]; then
    printf '%s/scripts/%s\n' "$SCRIPT_DIR" "$name"
  else
    printf '%s/scripts/%s\n' "$OPENHOUSE_DIR" "$name"
  fi
}

root_path() {
  if [ -d "$SCRIPT_DIR/scripts" ]; then
    printf '%s\n' "$SCRIPT_DIR"
  else
    printf '%s\n' "$OPENHOUSE_DIR"
  fi
}

run_stage() {
  local name="$1"
  shift || true
  local path
  local root
  path="$(script_path "$name")"
  root="$(root_path)"
  [ -f "$path" ] || die "缺少阶段脚本：$path"
  chmod +x "$path"
  log "开始：$name"
  OPENHOUSE_PORT="$OPENHOUSE_PORT" OPENHOUSE_ROOT="$root" bash "$path" "$@"
  log "完成：$name"
}

run_full_install() {
  run_stage 00-check-termux.sh
  run_stage 10-prepare-termux.sh
  run_stage 70-configure-entry.sh apply
  run_stage 20-install-ubuntu.sh
  run_stage 30-update-ubuntu-packages.sh
  run_stage 40-install-opencode.sh
  run_stage 42-install-codex.sh
  run_stage 44-install-claude-code.sh
  run_stage 50-install-ai-agents-skill.sh
  run_stage 60-start-opencode.sh
}

show_menu() {
  cat <<EOF
OpenHouse Installer

1. 完整安装并启动 OpenCode
2. 只检查 Termux 环境
3. 只准备 Termux 路径和基础包
4. 只安装 Ubuntu
5. 只更新 Ubuntu 软件包
6. 只安装 OpenCode
7. 只安装 Codex
8. 只安装 Claude Code
9. 只写入 Agent skills
10. 只启动 OpenCode
11. 启动入口：打开 Termux 后直接进入 Ubuntu
12. 启动入口：打开 Termux 后停留在 Termux
13. 查看启动入口设置
14. 启动本地网页维护器
15. 停止本地网页维护器
16. 查看本地网页维护器状态
17. 退出

当前端口：$OPENHOUSE_PORT
EOF
}

main() {
  ensure_termux
  ensure_local_layout

  case "${1:-}" in
    full)
      run_full_install
      return
      ;;
    check)
      run_stage 00-check-termux.sh
      return
      ;;
    prepare)
      run_stage 10-prepare-termux.sh
      run_stage 70-configure-entry.sh apply
      return
      ;;
    ubuntu)
      run_stage 20-install-ubuntu.sh
      return
      ;;
    ubuntu-packages)
      run_stage 30-update-ubuntu-packages.sh
      return
      ;;
    opencode)
      run_stage 40-install-opencode.sh
      return
      ;;
    codex)
      run_stage 42-install-codex.sh
      return
      ;;
    claude-code)
      run_stage 44-install-claude-code.sh
      return
      ;;
    skills)
      run_stage 50-install-ai-agents-skill.sh
      return
      ;;
    start)
      run_stage 60-start-opencode.sh
      return
      ;;
    entry-ubuntu)
      run_stage 70-configure-entry.sh ubuntu
      return
      ;;
    entry-termux)
      run_stage 70-configure-entry.sh termux
      return
      ;;
    entry-status)
      run_stage 70-configure-entry.sh status
      return
      ;;
    web|web-start)
      run_stage 80-openhouse-web.sh start
      return
      ;;
    web-stop)
      run_stage 80-openhouse-web.sh stop
      return
      ;;
    web-status)
      run_stage 80-openhouse-web.sh status
      return
      ;;
    ""|menu)
      ;;
    *)
      die "未知命令：$1"
      ;;
  esac

  while true; do
    show_menu
    printf '请选择 [1-17]: '
    read -r choice
    case "$choice" in
      1) run_full_install ;;
      2) run_stage 00-check-termux.sh ;;
      3) run_stage 10-prepare-termux.sh ;;
      4) run_stage 20-install-ubuntu.sh ;;
      5) run_stage 30-update-ubuntu-packages.sh ;;
      6) run_stage 40-install-opencode.sh ;;
      7) run_stage 42-install-codex.sh ;;
      8) run_stage 44-install-claude-code.sh ;;
      9) run_stage 50-install-ai-agents-skill.sh ;;
      10) run_stage 60-start-opencode.sh ;;
      11) run_stage 70-configure-entry.sh ubuntu ;;
      12) run_stage 70-configure-entry.sh termux ;;
      13) run_stage 70-configure-entry.sh status ;;
      14) run_stage 80-openhouse-web.sh start ;;
      15) run_stage 80-openhouse-web.sh stop ;;
      16) run_stage 80-openhouse-web.sh status ;;
      17) exit 0 ;;
      *) log "请输入 1 到 17。" ;;
    esac
  done
}

main "$@"
