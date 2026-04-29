#!/usr/bin/env bash
set -euo pipefail

OPENHOUSE_PORT="${OPENHOUSE_PORT:-8765}"

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

is_web_ready() {
  proot-distro login ubuntu -- bash -lc "curl -fsS --max-time 3 http://127.0.0.1:$OPENHOUSE_PORT/ >/dev/null 2>&1"
}

if is_web_ready; then
  log "OpenCode 已可通过 http://127.0.0.1:$OPENHOUSE_PORT/ 访问。"
  exit 0
fi

run_logged proot-distro login ubuntu -- bash -lc 'set -euo pipefail
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
if ! command -v opencode >/dev/null 2>&1 && ! test -x "$HOME/.opencode/bin/opencode"; then
  echo "尚未安装 OpenCode，请先运行：bash bootstrap.sh opencode" >&2
  exit 3
fi'

log "正在通过端口 $OPENHOUSE_PORT 启动 OpenCode。"
nohup proot-distro login ubuntu -- bash -lc "set -euo pipefail; export PATH=\"\$HOME/.opencode/bin:\$HOME/.local/bin:\$PATH\"; export BROWSER=/bin/true; exec opencode web --hostname 127.0.0.1 --port $OPENHOUSE_PORT --print-logs >\"\$HOME/.opencode-web.log\" 2>&1" >/dev/null 2>&1 < /dev/null &

for _ in $(seq 1 30); do
  if is_web_ready; then
    log "OpenCode 已启动：http://127.0.0.1:$OPENHOUSE_PORT/"
    exit 0
  fi
  log "正在等待 OpenCode 监听端口 $OPENHOUSE_PORT"
  sleep 1
done

log "OpenCode 未能在端口 $OPENHOUSE_PORT 上成功启动。"
proot-distro login ubuntu -- bash -lc 'if test -f "$HOME/.opencode-web.log"; then tail -n 80 "$HOME/.opencode-web.log"; else echo "未找到 OpenCode 运行日志。"; fi' || true
exit 1
