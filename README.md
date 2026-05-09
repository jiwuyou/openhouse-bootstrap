# OpenHouse Bootstrap

OpenHouse Bootstrap is a script-first installer for running OpenCode and local AI agent setup inside official Termux or the OpenHouse Termux App fork.

It can be used independently from the APK:

1. Install official Termux.
2. Run one bootstrap command.
3. Install Ubuntu through `proot-distro`.
4. Install OpenCode.
5. Install Codex and Claude Code inside Ubuntu.
6. Write OpenCode skills for Agent installation, login, and third-party API configuration.
7. Start OpenCode on `127.0.0.1`.

The OpenHouse APK can also load `openhouse-manifest.json` as an online maintenance plugin source, so stage titles, descriptions, and bootstrap actions can change without rebuilding the APK.

## Local Use

From this directory:

```bash
bash bootstrap.sh
```

Full install without menu:

```bash
bash bootstrap.sh full
```

Install individual stages:

```bash
bash bootstrap.sh ubuntu
bash bootstrap.sh opencode
bash bootstrap.sh codex
bash bootstrap.sh claude-code
bash bootstrap.sh skills
bash bootstrap.sh required-components
bash bootstrap.sh start
```

Use a custom OpenCode port:

```bash
OPENHOUSE_PORT=8766 bash bootstrap.sh start
```

## GitHub One-Line Install

Run this in official Termux:

```bash
pkg update -y && pkg install -y curl ca-certificates && \
curl -fsSL https://raw.githubusercontent.com/jiwuyou/openhouse-bootstrap/main/bootstrap.sh -o ~/openhouse-bootstrap.sh && \
bash ~/openhouse-bootstrap.sh full
```

## Security

Do not hard-code API keys into this repository. The included skills show placeholder examples only. Users should configure provider keys locally with environment variables or official login flows.

## License

MIT. See [LICENSE](LICENSE).
