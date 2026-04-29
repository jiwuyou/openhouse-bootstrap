#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[OpenHouse] %s\n' "$*"
}

run_logged() {
  log "+ $*"
  "$@"
}

install_claude_current_ubuntu() {
  set -euo pipefail
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
if command -v claude >/dev/null 2>&1; then
  echo "Claude Code 已安装：$(command -v claude)"
  claude --version || true
  return 0
fi
if ! command -v npm >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt update
  apt install -y nodejs npm ca-certificates
fi
mkdir -p "$HOME/.npm-global/bin"
npm config set prefix "$HOME/.npm-global"
npm install -g @anthropic-ai/claude-code
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
command -v claude
claude --version || true
PATH_LINE="export PATH=\"\$HOME/.opencode/bin:\$HOME/.local/bin:\$HOME/.npm-global/bin:\$PATH\""
for PROFILE_FILE in "$HOME/.profile" "$HOME/.bashrc"; do
  touch "$PROFILE_FILE"
  if ! grep -Fq "$PATH_LINE" "$PROFILE_FILE"; then
    {
      printf "\n# OpenHouse agent tools\n"
      printf "%s\n" "$PATH_LINE"
    } >> "$PROFILE_FILE"
  fi
done
}

if command -v proot-distro >/dev/null 2>&1 && proot-distro login ubuntu -- true >/dev/null 2>&1; then
  log "正在 Ubuntu 内安装或检查 Claude Code。"
  run_logged proot-distro login ubuntu -- bash -s <<'EOF'
set -euo pipefail
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
if command -v claude >/dev/null 2>&1; then
  echo "Claude Code 已安装：$(command -v claude)"
  claude --version || true
  exit 0
fi
if ! command -v npm >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt update
  apt install -y nodejs npm ca-certificates
fi
mkdir -p "$HOME/.npm-global/bin"
npm config set prefix "$HOME/.npm-global"
npm install -g @anthropic-ai/claude-code
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
command -v claude
claude --version || true
PATH_LINE="export PATH=\"\$HOME/.opencode/bin:\$HOME/.local/bin:\$HOME/.npm-global/bin:\$PATH\""
for PROFILE_FILE in "$HOME/.profile" "$HOME/.bashrc"; do
  touch "$PROFILE_FILE"
  if ! grep -Fq "$PATH_LINE" "$PROFILE_FILE"; then
    {
      printf "\n# OpenHouse agent tools\n"
      printf "%s\n" "$PATH_LINE"
    } >> "$PROFILE_FILE"
  fi
done
EOF
elif [ -f /etc/os-release ] && grep -qi '^ID=ubuntu' /etc/os-release; then
  log "检测到当前已在 Ubuntu 内，直接安装或检查 Claude Code。"
  run_logged install_claude_current_ubuntu
else
  log "Ubuntu 不可用。请在 Termux 外层运行：bash bootstrap.sh ubuntu；或在 Ubuntu 内直接运行本脚本。"
  exit 2
fi

log "Claude Code 安装阶段完成。"
