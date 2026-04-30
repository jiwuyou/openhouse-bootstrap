# Security

OpenHouse Bootstrap downloads and executes maintenance scripts. Use only sources you trust.

Do not commit real API keys, provider tokens, local logs, or device-specific credentials.

The default online manifest is:

```text
https://raw.githubusercontent.com/jiwuyou/openhouse-bootstrap/main/openhouse-manifest.json
```

The scripts install tools inside the user's local Termux and Ubuntu environment. They do not include OpenAI, Anthropic, OpenRouter, or other provider credentials.
