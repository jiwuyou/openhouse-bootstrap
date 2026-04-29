#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[OpenHouse] %s\n' "$*"
}

run_logged() {
  log "+ $*"
  "$@"
}

codex_install_program() {
  cat <<'EOF'
set -euo pipefail

export PATH="$HOME/.local/node/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

ensure_node_npm() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    return 0
  fi

  NODE_DIST_BASE="${OPENHOUSE_NODE_DIST_BASE:-https://nodejs.org/dist/latest-v22.x}"
  NODE_ROOT="$HOME/.local/node"
  NODE_TMP="$HOME/.local/node-download"
  mkdir -p "$NODE_TMP" "$HOME/.local"

  echo "正在安装 Node.js 到 $NODE_ROOT"
  NODE_TARBALL="$(curl -fsSL "$NODE_DIST_BASE/SHASUMS256.txt" | awk '/linux-arm64.tar.gz$/ { print $2; exit }')"
  if [ -z "$NODE_TARBALL" ]; then
    echo "未能从 $NODE_DIST_BASE 找到 linux-arm64 Node.js 包。" >&2
    exit 5
  fi

  curl -fL "$NODE_DIST_BASE/$NODE_TARBALL" -o "$NODE_TMP/$NODE_TARBALL"
  rm -rf "$NODE_ROOT"
  mkdir -p "$NODE_ROOT"
  tar -xzf "$NODE_TMP/$NODE_TARBALL" -C "$NODE_ROOT" --strip-components=1
  rm -f "$NODE_TMP/$NODE_TARBALL"

  export PATH="$NODE_ROOT/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
  node -v
  npm -v
}

ensure_node_npm

if command -v codex >/dev/null 2>&1; then
  echo "Codex CLI 已安装：$(command -v codex)"
  codex --version || true
  exit 0
fi

mkdir -p "$HOME/.npm-global/bin"
npm config set prefix "$HOME/.npm-global"
npm install -g @openai/codex

export PATH="$HOME/.local/node/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
command -v codex
codex --version || true

PATH_LINE="export PATH=\"\$HOME/.local/node/bin:\$HOME/.opencode/bin:\$HOME/.local/bin:\$HOME/.npm-global/bin:\$PATH\""
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
}

if command -v proot-distro >/dev/null 2>&1 && proot-distro login ubuntu -- true >/dev/null 2>&1; then
  log "正在 Ubuntu 内安装或检查 Codex CLI。"
  run_logged proot-distro login ubuntu -- bash -s <<<"$(codex_install_program)"
elif [ -f /etc/os-release ] && grep -qi '^ID=ubuntu' /etc/os-release; then
  log "检测到当前已在 Ubuntu 内，直接安装或检查 Codex CLI。"
  run_logged bash -s <<<"$(codex_install_program)"
else
  log "Ubuntu 不可用。请在 Termux 外层运行：bash bootstrap.sh ubuntu；或在 Ubuntu 内直接运行本脚本。"
  exit 2
fi

log "Codex CLI 安装阶段完成。"
