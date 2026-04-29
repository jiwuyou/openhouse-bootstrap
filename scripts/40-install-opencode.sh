#!/usr/bin/env bash
set -euo pipefail

OPENCODE_INSTALL_URL="${OPENCODE_INSTALL_URL:-https://opencode.ai/install}"

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

log "正在 Ubuntu 内安装或检查 OpenCode。"
run_logged proot-distro login ubuntu -- env OPENCODE_INSTALL_URL="$OPENCODE_INSTALL_URL" bash -lc 'set -euo pipefail
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
if command -v opencode >/dev/null 2>&1 || test -x "$HOME/.opencode/bin/opencode"; then
  echo "OpenCode 已安装。"
else
  curl -fsSL "$OPENCODE_INSTALL_URL" | bash
fi
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
if command -v opencode >/dev/null 2>&1; then
  command -v opencode
elif test -x "$HOME/.opencode/bin/opencode"; then
  echo "$HOME/.opencode/bin/opencode"
else
  echo "OpenCode 安装后仍未找到可执行文件。" >&2
  exit 4
fi'

log "正在写入 Ubuntu 内的产品路径提示。"
run_logged proot-distro login ubuntu -- bash -lc 'set -euo pipefail
mkdir -p "$HOME/product-links" "$HOME/workspace"
printf "%s\n" "/data/data/com.termux/files/home/product-docs" > "$HOME/product-links/docs-path.txt"
printf "%s\n" "/data/data/com.termux/files/home/workspace" > "$HOME/product-links/workspace-path.txt"
echo "文档路径：$(cat "$HOME/product-links/docs-path.txt")"
echo "工作区路径：$(cat "$HOME/product-links/workspace-path.txt")"'

log "OpenCode 安装阶段完成。"
