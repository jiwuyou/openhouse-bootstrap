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

if ! command -v proot-distro >/dev/null 2>&1 || ! proot-distro login ubuntu -- true >/dev/null 2>&1; then
  log "Ubuntu 不可用，请先运行：bash bootstrap.sh ubuntu"
  exit 2
fi

for skill in system-environment-description install-ai-agents; do
  src="$OPENHOUSE_ROOT/skills/$skill/SKILL.md"
  [ -f "$src" ] || {
    log "缺少 skill 文件：$src"
    exit 3
  }
done

TMP_DIR="$HOME/.openhouse-bootstrap/tmp-skills"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cp -R "$OPENHOUSE_ROOT/skills/system-environment-description" "$TMP_DIR/"
cp -R "$OPENHOUSE_ROOT/skills/install-ai-agents" "$TMP_DIR/"

log "正在写入 OpenCode 用户级 skills。"
run_logged proot-distro login ubuntu -- bash -lc 'set -euo pipefail
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
if ! command -v opencode >/dev/null 2>&1 && ! test -x "$HOME/.opencode/bin/opencode"; then
  echo "尚未安装 OpenCode，请先运行：bash bootstrap.sh opencode" >&2
  exit 4
fi'

run_logged proot-distro login ubuntu -- bash -lc 'set -euo pipefail
mkdir -p "$HOME/.config/opencode/skills"
cp -R /data/data/com.termux/files/home/.openhouse-bootstrap/tmp-skills/system-environment-description "$HOME/.config/opencode/skills/"
cp -R /data/data/com.termux/files/home/.openhouse-bootstrap/tmp-skills/install-ai-agents "$HOME/.config/opencode/skills/"
echo "系统环境说明技能目录：$HOME/.config/opencode/skills/system-environment-description"
echo "Agent 安装配置技能目录：$HOME/.config/opencode/skills/install-ai-agents"'

rm -rf "$TMP_DIR"
log "OpenCode skills 写入完成。"
