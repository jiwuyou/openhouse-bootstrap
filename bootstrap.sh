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

download_file() {
  local url="$1"
  local output="$2"
  local attempt
  for attempt in 1 2 3 4 5; do
    log "下载：$url（第 $attempt 次）"
    if curl -fL --connect-timeout 20 --retry 3 --retry-delay 2 --retry-all-errors "$url" -o "$output"; then
      return 0
    fi
    sleep 2
  done
  return 1
}

is_termux() {
  [ -n "${PREFIX:-}" ] && [ -d "${PREFIX:-}/bin" ] && [ -d "/data/data/com.termux/files" ]
}

is_current_ubuntu() {
  [ -f /etc/os-release ] && grep -qi '^ID=ubuntu' /etc/os-release
}

detect_openhouse_runtime() {
  if is_current_ubuntu; then
    printf 'ubuntu'
    return 0
  fi

  if [ -x "${PREFIX:-/data/data/com.termux/files/usr}/bin/openhouse-env-probe" ]; then
    "${PREFIX:-/data/data/com.termux/files/usr}/bin/openhouse-env-probe" 2>/dev/null \
      | awk -F= '$1=="OPENHOUSE_RUNTIME"{print $2; found=1} END{if(!found) exit 1}' \
      && return 0
  fi

  if is_termux; then
    printf 'termux'
    return 0
  fi

  printf 'unknown'
}

run_environment_probe() {
  local probe="${PREFIX:-/data/data/com.termux/files/usr}/bin/openhouse-env-probe"
  if [ -x "$probe" ]; then
    log "正在执行环境探测命令：$probe"
    run_logged "$probe" || true
  else
    log "环境探测命令不存在，使用内置探测逻辑。"
  fi
  log "当前运行环境：$(detect_openhouse_runtime)"
}

ensure_termux() {
  is_termux || die "请在官方 Termux 内运行，不要在 Android adb shell 或普通 Linux 主机运行。"
}

ensure_supported_runtime() {
  is_termux || is_current_ubuntu || die "请在官方 Termux 内运行；Codex、Claude Code 等 agent 安装也可以在 OpenHouse Ubuntu 内运行。"
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
    55-install-required-components.sh \
    60-start-opencode.sh \
    70-configure-entry.sh \
    80-openhouse-web.sh; do
    download_file "$OPENHOUSE_RAW_BASE/scripts/$name" "$OPENHOUSE_DIR/scripts/$name"
    chmod +x "$OPENHOUSE_DIR/scripts/$name"
  done

  mkdir -p \
    "$OPENHOUSE_DIR/skills/system-environment-description" \
    "$OPENHOUSE_DIR/skills/install-ai-agents"
  download_file "$OPENHOUSE_RAW_BASE/skills/system-environment-description/SKILL.md" \
    "$OPENHOUSE_DIR/skills/system-environment-description/SKILL.md"
  download_file "$OPENHOUSE_RAW_BASE/skills/install-ai-agents/SKILL.md" \
    "$OPENHOUSE_DIR/skills/install-ai-agents/SKILL.md"
}

ensure_termux_curl() {
  if ! is_termux; then
    command -v curl >/dev/null 2>&1 && curl --version >/dev/null 2>&1 && return 0
    die "curl 不可用，且当前不是 Termux，无法自动修复。"
  fi

  command -v pkg >/dev/null 2>&1 || die "curl 不可用，且缺少 pkg，无法自动修复。"

  log "正在更新 Termux 包索引并修复 curl 网络依赖。"
  run_logged pkg update -y || true
  run_logged pkg install -y curl libcurl libngtcp2 libnghttp2 openssl ca-certificates || true

  if command -v curl >/dev/null 2>&1 && curl --version >/dev/null 2>&1; then
    return 0
  fi

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
  run_environment_probe
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
  run_stage 55-install-required-components.sh
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
10. 安装 OpenHouse 必要组件
11. 只启动 OpenCode
12. 启动入口：打开 Termux 后直接进入 Ubuntu
13. 启动入口：打开 Termux 后停留在 Termux
14. 查看启动入口设置
15. 启动本地网页维护器
16. 停止本地网页维护器
17. 查看本地网页维护器状态
18. 退出

当前端口：$OPENHOUSE_PORT
EOF
}

main() {
  ensure_supported_runtime
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
    required-components|runtime-components|components)
      run_stage 55-install-required-components.sh
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
    printf '请选择 [1-18]: '
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
      10) run_stage 55-install-required-components.sh ;;
      11) run_stage 60-start-opencode.sh ;;
      12) run_stage 70-configure-entry.sh ubuntu ;;
      13) run_stage 70-configure-entry.sh termux ;;
      14) run_stage 70-configure-entry.sh status ;;
      15) run_stage 80-openhouse-web.sh start ;;
      16) run_stage 80-openhouse-web.sh stop ;;
      17) run_stage 80-openhouse-web.sh status ;;
      18) exit 0 ;;
      *) log "请输入 1 到 18。" ;;
    esac
  done
}

main "$@"
