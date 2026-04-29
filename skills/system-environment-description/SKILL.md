---
name: system-environment-description
description: Use when an agent needs to understand the OpenHouse runtime layout, Termux/Ubuntu boundary, stable paths, workspace rules, or local service ports.
---

# System Environment Description

You are operating inside OpenHouse on Android:

- Host shell: Termux
- Main Linux runtime: Ubuntu through `proot-distro`
- User workspace: `/data/data/com.termux/files/home/workspace`
- Product docs: `/data/data/com.termux/files/home/product-docs`
- Ubuntu short paths may mirror these through files under `~/product-links`

## Rules

- Treat `~/workspace` as the primary writable project area.
- Read product docs before making broad environment assumptions.
- Do not scan the whole Termux home unless the user asks for it.
- Keep local web services bound to `127.0.0.1` unless the user explicitly asks for remote access.
- Never write API keys or tokens into project files, docs, logs, or shell scripts.

## Useful Checks

```bash
pwd
whoami
command -v opencode || true
cat "$HOME/product-links/docs-path.txt" 2>/dev/null || true
cat "$HOME/product-links/workspace-path.txt" 2>/dev/null || true
```

## Service Defaults

- OpenCode web: `http://127.0.0.1:8765/`
- OpenHouse bootstrap scripts: Termux side, normally `~/openhouse-bootstrap` or `~/.openhouse-bootstrap`
- OpenCode user skills: Ubuntu side, `~/.config/opencode/skills`
