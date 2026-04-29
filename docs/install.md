# Install

Install official Termux first. Do not run these scripts from Android `adb shell`.

## Interactive Install

```bash
bash bootstrap.sh
```

## Full Install

```bash
bash bootstrap.sh full
```

## Individual Stages

```bash
bash bootstrap.sh check
bash bootstrap.sh prepare
bash bootstrap.sh ubuntu
bash bootstrap.sh ubuntu-packages
bash bootstrap.sh opencode
bash bootstrap.sh skills
bash bootstrap.sh start
```

All stages are designed to be safe to run again after interruption.

## Result

Default OpenCode URL:

```text
http://127.0.0.1:8765/
```

Default workspace:

```text
/data/data/com.termux/files/home/workspace
```

Product docs:

```text
/data/data/com.termux/files/home/product-docs
```
