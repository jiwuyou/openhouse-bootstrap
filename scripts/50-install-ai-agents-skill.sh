#!/usr/bin/env bash
set -euo pipefail

OPENHOUSE_ROOT="${OPENHOUSE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

log() {
  printf '[OpenHouse] %s\n' "$*"
}

run_logged() {
  log "+ $*"
  "$@"
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
  CURRENT_RUNTIME="$(detect_openhouse_runtime)"
  log "当前运行环境：$CURRENT_RUNTIME"
}

run_ubuntu_logged() {
  if is_current_ubuntu; then
    run_logged "$@"
    return $?
  fi

  run_logged proot-distro login ubuntu -- "$@"
}

require_ubuntu_target() {
  if is_current_ubuntu; then
    return 0
  fi

  if ! command -v proot-distro >/dev/null 2>&1 || ! proot-distro login ubuntu -- true >/dev/null 2>&1; then
    log "Ubuntu 不可用，请先运行：bash bootstrap.sh ubuntu"
    exit 2
  fi
}

write_skills_to_ubuntu() {
  if is_current_ubuntu; then
    mkdir -p "$HOME/.config/opencode/skills"
    rm -rf \
      "$HOME/.config/opencode/skills/system-environment-description" \
      "$HOME/.config/opencode/skills/install-ai-agents"
    cp -R "$OPENHOUSE_ROOT/skills/system-environment-description" "$HOME/.config/opencode/skills/"
    cp -R "$OPENHOUSE_ROOT/skills/install-ai-agents" "$HOME/.config/opencode/skills/"
    echo "系统环境说明技能目录：$HOME/.config/opencode/skills/system-environment-description"
    echo "Agent 安装配置技能目录：$HOME/.config/opencode/skills/install-ai-agents"
    return 0
  fi

  (
    cd "$OPENHOUSE_ROOT/skills"
    tar -cf - system-environment-description install-ai-agents
  ) | run_ubuntu_logged bash -lc 'set -euo pipefail
mkdir -p "$HOME/.config/opencode/skills"
rm -rf \
  "$HOME/.config/opencode/skills/system-environment-description" \
  "$HOME/.config/opencode/skills/install-ai-agents"
tar -xf - -C "$HOME/.config/opencode/skills"
echo "系统环境说明技能目录：$HOME/.config/opencode/skills/system-environment-description"
echo "Agent 安装配置技能目录：$HOME/.config/opencode/skills/install-ai-agents"'
}

log "正在探测当前维护脚本运行环境。"
run_environment_probe
if [ "$CURRENT_RUNTIME" = "ubuntu" ]; then
  log "已在 Ubuntu 内，将直接写入 Ubuntu 用户级 OpenCode skills。"
else
  log "当前不在 Ubuntu 内，将通过 proot-distro 进入 Ubuntu 后写入 OpenCode skills。"
fi

require_ubuntu_target

for skill in system-environment-description install-ai-agents; do
  src="$OPENHOUSE_ROOT/skills/$skill/SKILL.md"
  [ -f "$src" ] || {
    log "缺少 skill 文件：$src"
    exit 3
  }
done

log "正在检查 OpenCode 是否已安装。"
run_ubuntu_logged bash -lc 'set -euo pipefail
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
if ! command -v opencode >/dev/null 2>&1 && ! test -x "$HOME/.opencode/bin/opencode"; then
  echo "尚未安装 OpenCode，请先运行：bash bootstrap.sh opencode" >&2
  exit 4
fi'

log "正在写入 OpenCode 用户级 skills。"
write_skills_to_ubuntu
log "OpenCode skills 写入完成。"
