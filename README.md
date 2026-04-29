# OpenHouse Bootstrap

OpenHouse Bootstrap is a script-first installer for running OpenCode and local AI agent setup inside official Termux.

This project replaces a custom APK flow with:

1. Install official Termux.
2. Run one bootstrap command.
3. Install Ubuntu through `proot-distro`.
4. Install OpenCode.
5. Write OpenCode skills for Agent installation, login, and third-party API configuration.
6. Start OpenCode on `127.0.0.1`.

## Local Use

From this directory:

```bash
bash bootstrap.sh
```

Full install without menu:

```bash
bash bootstrap.sh full
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

Do not hard-code API keys into this repository.
