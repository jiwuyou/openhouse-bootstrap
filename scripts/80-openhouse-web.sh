#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-start}"
TERMUX_HOME="${HOME:-/data/data/com.termux/files/home}"
OPENHOUSE_DIR="$TERMUX_HOME/.openhouse"
WEB_DIR="$OPENHOUSE_DIR/web"
SERVER_FILE="$WEB_DIR/openhouse_web_server.py"
PID_FILE="$OPENHOUSE_DIR/web.pid"
LOG_FILE="$OPENHOUSE_DIR/web.log"
PORT_FILE="$OPENHOUSE_DIR/web-port"
PORT="${OPENHOUSE_WEB_PORT:-}"
REQUESTED_PORT="${OPENHOUSE_WEB_PORT:-}"

log() {
  printf '[OpenHouse] %s\n' "$*"
}

is_current_ubuntu() {
  [ -f /etc/os-release ] && grep -qi '^ID=ubuntu' /etc/os-release
}

is_termux() {
  [ -n "${PREFIX:-}" ] && [ -d "${PREFIX:-}/bin" ] && [ -d "/data/data/com.termux/files" ]
}

ensure_port() {
  mkdir -p "$OPENHOUSE_DIR"
  if [ -z "$PORT" ]; then
    if [ -f "$PORT_FILE" ]; then
      PORT="$(tr -d '[:space:]' < "$PORT_FILE")"
    else
      PORT="38423"
      printf '%s\n' "$PORT" > "$PORT_FILE"
    fi
  fi
  case "$PORT" in
    ''|*[!0-9]*) log "端口必须是数字：$PORT"; exit 2 ;;
  esac
  if [ "$PORT" -lt 10000 ] || [ "$PORT" -gt 65535 ]; then
    log "端口必须是 10000 到 65535 的 5 位端口：$PORT"
    exit 2
  fi
  if [ -n "$REQUESTED_PORT" ]; then
    printf '%s\n' "$PORT" > "$PORT_FILE"
  fi
}

write_server() {
  mkdir -p "$WEB_DIR"
  cat > "$SERVER_FILE" <<'PY'
#!/usr/bin/env python3
import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOME = os.environ.get("HOME", "/data/data/com.termux/files/home")
BOOTSTRAP = os.path.join(HOME, "openhouse-bootstrap.sh")
RAW_BOOTSTRAP = "https://raw.githubusercontent.com/jiwuyou/openhouse-bootstrap/main/bootstrap.sh"
LOG_DIR = os.path.join(HOME, ".openhouse", "web-runs")
ALLOWED = {
    "full", "check", "prepare", "ubuntu", "ubuntu-packages",
    "opencode", "codex", "claude-code", "skills", "start",
    "entry-ubuntu", "entry-termux", "entry-status", "web-status"
}

INDEX = """<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>OpenHouse 本地网页维护器</title>
  <style>
    :root{font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#18231f;background:#f5f7f2}
    body{margin:0;padding:18px}
    main{max-width:780px;margin:0 auto}
    h1{font-size:26px;margin:0 0 8px}
    p{color:#63716a;line-height:1.6}
    section{background:#fff;border:1px solid #dfe6df;border-radius:8px;padding:14px;margin-top:14px}
    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:10px}
    button{border:0;border-radius:7px;padding:12px;background:#d8f0e4;color:#0e563b;font-weight:700;text-align:left}
    button.primary{background:#0f7d58;color:#fff}
    pre{white-space:pre-wrap;background:#07100b;color:#a8f0bf;border-radius:8px;padding:12px;min-height:180px;overflow:auto}
  </style>
</head>
<body>
<main>
  <h1>OpenHouse 本地网页维护器</h1>
  <p>服务运行在 127.0.0.1，只执行白名单维护动作。先完成 APK 里的后台权限，再在这里执行安装和设置。</p>
  <section>
    <h2>阶段操作</h2>
    <div class="grid">
      <button class="primary" data-action="full">完整安装</button>
      <button data-action="prepare">准备环境</button>
      <button data-action="ubuntu">安装 Ubuntu</button>
      <button data-action="ubuntu-packages">更新 Ubuntu 包</button>
      <button data-action="opencode">安装 OpenCode</button>
      <button data-action="codex">安装 Codex</button>
      <button data-action="claude-code">安装 Claude Code</button>
      <button data-action="skills">写入 Agent Skills</button>
      <button data-action="start">启动 OpenCode</button>
    </div>
  </section>
  <section>
    <h2>启动入口设置</h2>
    <div class="grid">
      <button data-action="entry-ubuntu">打开 Termux 后进入 Ubuntu</button>
      <button data-action="entry-termux">打开 Termux 后停留 Termux</button>
      <button data-action="entry-status">查看当前设置</button>
    </div>
  </section>
  <section>
    <h2>日志</h2>
    <pre id="log">等待操作。</pre>
  </section>
</main>
<script>
const log = document.querySelector("#log");
async function run(action) {
  log.textContent = "正在执行：" + action + "\\n";
  const response = await fetch("/api/run", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({action})
  });
  const data = await response.json();
  log.textContent = data.output || data.error || JSON.stringify(data, null, 2);
}
document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-action]");
  if (button) run(button.dataset.action).catch(error => log.textContent = String(error));
});
</script>
</body>
</html>"""

def ensure_bootstrap():
    if os.path.exists(BOOTSTRAP):
        return
    subprocess.run(["curl", "-fsSL", RAW_BOOTSTRAP, "-o", BOOTSTRAP], check=True)

class Handler(BaseHTTPRequestHandler):
    def _json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/" or self.path.startswith("/index.html"):
            body = INDEX.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/api/status":
            self._json(200, {"ok": True, "allowed": sorted(ALLOWED)})
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path != "/api/run":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
        action = str(payload.get("action", ""))
        if action not in ALLOWED:
            self._json(400, {"error": "unsupported action: " + action})
            return
        try:
            ensure_bootstrap()
            os.makedirs(LOG_DIR, exist_ok=True)
            result = subprocess.run(
                ["bash", BOOTSTRAP, action],
                cwd=HOME,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=3600,
            )
            self._json(200, {"ok": result.returncode == 0, "exitCode": result.returncode, "output": result.stdout})
        except Exception as exc:
            self._json(500, {"error": str(exc)})

    def log_message(self, fmt, *args):
        return

if __name__ == "__main__":
    port = int(os.environ.get("OPENHOUSE_WEB_PORT", "38423"))
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
PY
  chmod 700 "$SERVER_FILE"
}

is_running() {
  [ -f "$PID_FILE" ] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1
}

ensure_python() {
  PYTHON_BIN=""
  PYTHON_ENV_MODE="default"

  if is_current_ubuntu; then
    if [ ! -x /usr/bin/python3 ]; then
      log "Ubuntu 内缺少 python3，正在安装。"
      apt update
      DEBIAN_FRONTEND=noninteractive apt install -y python3
    fi
    PYTHON_BIN="/usr/bin/python3"
    PYTHON_ENV_MODE="ubuntu"
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
    return
  fi

  if is_termux; then
    log "缺少 python3，正在安装。"
    pkg update -y
    pkg install -y python
    PYTHON_BIN="$(command -v python3)"
    return
  fi

  log "缺少 python3，且当前环境无法自动安装。"
  exit 3
}

start_server() {
  local previous_port=""
  [ -f "$PORT_FILE" ] && previous_port="$(tr -d '[:space:]' < "$PORT_FILE" 2>/dev/null || true)"
  ensure_port
  write_server
  if is_running; then
    if [ -n "$REQUESTED_PORT" ] && [ -n "$previous_port" ] && [ "$previous_port" != "$PORT" ]; then
      log "本地网页维护器端口从 $previous_port 调整为 $PORT，正在重启。"
      kill "$(cat "$PID_FILE")" || true
      rm -f "$PID_FILE"
      sleep 1
    else
      log "本地网页维护器已运行：http://127.0.0.1:$PORT/"
      return
    fi
  fi
  ensure_python
  log "使用 Python：$PYTHON_BIN"
  if [ "$PYTHON_ENV_MODE" = "ubuntu" ]; then
    nohup env -u LD_LIBRARY_PATH \
      HOME="$TERMUX_HOME" \
      OPENHOUSE_WEB_PORT="$PORT" \
      PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
      "$PYTHON_BIN" "$SERVER_FILE" > "$LOG_FILE" 2>&1 &
  else
    nohup env HOME="$TERMUX_HOME" OPENHOUSE_WEB_PORT="$PORT" "$PYTHON_BIN" "$SERVER_FILE" > "$LOG_FILE" 2>&1 &
  fi
  echo "$!" > "$PID_FILE"
  sleep 1
  if is_running; then
    log "本地网页维护器已启动：http://127.0.0.1:$PORT/"
  else
    log "本地网页维护器启动失败。日志：$LOG_FILE"
    [ -f "$LOG_FILE" ] && tail -n 80 "$LOG_FILE" || true
    exit 1
  fi
}

stop_server() {
  if is_running; then
    kill "$(cat "$PID_FILE")" || true
    rm -f "$PID_FILE"
    log "本地网页维护器已停止。"
  else
    log "本地网页维护器未运行。"
  fi
}

status_server() {
  ensure_port
  if is_running; then
    log "本地网页维护器运行中：http://127.0.0.1:$PORT/"
  else
    log "本地网页维护器未运行。"
  fi
  log "端口配置：$PORT_FILE"
  log "服务日志：$LOG_FILE"
}

case "$MODE" in
  start|web-start) start_server ;;
  stop|web-stop) stop_server ;;
  status|web-status) status_server ;;
  *) log "未知网页维护器命令：$MODE"; exit 2 ;;
esac
