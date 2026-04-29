# Permissions

Android permissions cannot be granted by a shell script. The bootstrap scripts only show reminders.

## Shared Storage

If you need access to shared storage:

```bash
termux-setup-storage
```

Then accept the Android permission prompt.

## Battery Optimization

For long-running OpenCode sessions, manually allow Termux to ignore battery optimization in Android system settings.

Suggested path varies by device vendor:

```text
Settings -> Apps -> Termux -> Battery -> Unrestricted / Don't optimize
```

## Overlay

Overlay permission is optional. It is only needed if a future launcher or floating helper requires it.

## Remote Access

OpenHouse starts services on `127.0.0.1` by default. Do not bind OpenCode, OpenClaw, or model gateways to `0.0.0.0` unless you understand the network and token risk.
