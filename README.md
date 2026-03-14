# OpenClaw Bootstrap

A guided setup skill for new OpenClaw instances. When an OpenClaw agent reads this repository, it walks the user through setting up:

1. **System packages** — `gh`, `cloudflared`, `jq`, Playwright
2. **GitHub CLI** — authenticate, configure git identity
3. **Cloudflare Tunnel** — connect a domain for app deployments
4. **Coolify** — self-hosted PaaS integration (API + project setup)
5. **LLM Proxy** — optional OpenAI-compatible proxy for sub-agents
6. **ClawHub Skills** — install recommended skill packs
7. **Custom Models** — configure `config.yaml` with proxy models
8. **Workspace Files** — generate TOOLS.md, AGENTS.md, SOUL.md, USER.md

## Usage

Point your OpenClaw agent at this repo:

```
Read https://github.com/YOUR_USER/openclaw-bootstrap and follow the setup guide.
```

Or clone it into your workspace and tell the agent to read `SKILL.md`.

## What It Does

- Installs all required CLI tools
- Prompts you for API keys interactively (never hardcodes them)
- Tests every credential before saving
- Writes config files to `~/.openclaw/` and workspace
- Sets up git identity, Cloudflare tunnel routes, Coolify projects
- Everything is idempotent — safe to re-run

## Requirements

- A running OpenClaw instance (gateway + agent)
- Linux environment (Debian/Ubuntu preferred)
- Root or sudo access for package installation
- API keys ready: GitHub PAT, Cloudflare API token, Coolify API token (optional)

## License

MIT
