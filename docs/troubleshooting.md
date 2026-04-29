# Troubleshooting

## Wrong Shell

If you see:

```text
请在官方 Termux 内运行
```

Open Termux and run the command there. Do not use Android `adb shell`.

## GitHub Raw Download Fails

Install curl and certificates:

```bash
pkg update -y
pkg install -y curl ca-certificates
```

If the network still blocks GitHub raw URLs, use a mirror or download the repository zip manually.

## Ubuntu Install Fails

Retry:

```bash
bash bootstrap.sh prepare
bash bootstrap.sh ubuntu
```

If `proot-distro` is broken, reinstall it:

```bash
pkg reinstall proot-distro
```

## OpenCode Does Not Start

Check if the port is already used:

```bash
proot-distro login ubuntu -- bash -lc 'ss -ltnp | grep 8765 || true'
```

Start on another port:

```bash
OPENHOUSE_PORT=8766 bash bootstrap.sh start
```

Check logs:

```bash
proot-distro login ubuntu -- bash -lc 'tail -n 120 ~/.opencode-web.log'
```

## Agent Login

OpenCode, Codex, and Claude Code each own their login flow. Use the `install-ai-agents` OpenCode skill after installation for official login commands and third-party API examples.
