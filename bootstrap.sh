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

  command -v curl >/dev/null 2>&1 || die "缺少 curl，请先运行：pkg install -y curl"

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
    60-start-opencode.sh; do
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
11. 退出

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
    ""|menu)
      ;;
    *)
      die "未知命令：$1"
      ;;
  esac

  while true; do
    show_menu
    printf '请选择 [1-11]: '
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
      11) exit 0 ;;
      *) log "请输入 1 到 11。" ;;
    esac
  done
}

main "$@"
