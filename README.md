# OpenClaw Bootstrap

A guided setup skill for new OpenClaw instances. When an OpenClaw agent reads this repository, it walks the user through setting up their full environment interactively — prompting for API keys, testing every credential, and configuring everything step by step.

## What Gets Set Up

1. **System packages** — `gh`, `cloudflared`, `jq`, Playwright
2. **GitHub CLI** — authenticate with PAT, configure git identity, test repo creation
3. **Cloudflare Tunnel** — connect a domain, discover/create tunnels, list subdomains
4. **Coolify** — self-hosted PaaS integration, discover servers/projects/apps (optional)
5. **LLM Proxy** — OpenAI-compatible proxy for sub-agents with custom models (optional)
6. **ClawHub Skills** — install recommended skill packs
7. **Custom Models** — configure `config.yaml` with proxy models + aliases for sub-agents
8. **Browser Automation** — Playwright Chromium install + openclaw.json browser config
9. **Workspace Files** — generate TOOLS.md, AGENTS.md, SOUL.md, USER.md, MEMORY.md, IDENTITY.md

## Usage

Point your OpenClaw agent at this repo:

```
Read https://github.com/Zebratic/openclaw-bootstrap and follow the setup guide.
```

Or clone it into your workspace and tell the agent to read `SKILL.md`.

## What It Does

- Installs all required CLI tools (skips what's already present)
- Prompts you for API keys interactively — **never hardcodes anything**
- Tests every credential before saving
- Writes config files to `~/.openclaw/` and workspace
- Sets up git identity, Cloudflare tunnel routes, Coolify discovery
- Includes a validation script that checks all integrations
- Everything is idempotent — safe to re-run

## API Key Permissions

| Service | Required Permissions |
|---------|---------------------|
| **GitHub PAT** (fine-grained) | Contents R/W, Metadata R, PRs R/W, Actions R, Administration R/W |
| **GitHub PAT** (classic) | `repo`, `workflow`, `read:org` |
| **Cloudflare** | Zone:DNS:Edit, Zone:Zone:Read, Account:Cloudflare Tunnel:Edit/Read |
| **Coolify** | Root API token (admin account — no granular scopes) |
| **LLM Proxy** | Any valid API key with model access |

## Requirements

- A running OpenClaw instance (gateway + agent)
- Linux environment (Debian/Ubuntu preferred)
- Root or sudo access for package installation
- API keys ready (GitHub required, others optional)

## Post-Setup Validation

Run the included validation script:

```bash
bash scripts/validate.sh
```

## License

MIT
