# OpenClaw Bootstrap Skill

You are guiding a user through setting up a fresh OpenClaw instance with full infrastructure integration. This is an interactive setup — prompt the user in chat for every secret/credential. NEVER hardcode or assume any API keys, domains, usernames, or personal information.

## Overview

Tell the user upfront what you'll set up:

```
🚀 OpenClaw Bootstrap — Full Environment Setup

I'll walk you through setting up:
1. System packages (gh, cloudflared, jq, playwright)
2. GitHub CLI authentication + git identity
3. Cloudflare Tunnel (connect your domain)
4. Coolify PaaS integration (optional)
5. LLM Proxy for sub-agents (optional)
6. ClawHub skills installation
7. Custom model config for sub-agents
8. Workspace files (TOOLS.md, USER.md, etc.)

Each step tests credentials before saving. You can skip optional steps.
Ready? Let's go.
```

## Step 1: System Packages

Install required CLI tools. Run each and report results to user.

```bash
# GitHub CLI
(command -v gh > /dev/null) || {
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  apt update && apt install -y gh
}

# Cloudflared
(command -v cloudflared > /dev/null) || {
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-main.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflared.list
  apt update && apt install -y cloudflared
}

# Other essentials
apt install -y jq curl python3 python3-pip

# Playwright (for browser testing)
npm install -g @playwright/test
npx playwright install chromium --with-deps
```

Tell the user what was installed and versions.

## Step 2: GitHub CLI

**Ask the user:**
- "Please provide your GitHub Personal Access Token (PAT). It needs these scopes: `repo`, `read:org`, `workflow`, `admin:repo_hook`. You can create one at https://github.com/settings/tokens"

**After receiving the token:**

```bash
# Authenticate
echo "<TOKEN>" | gh auth login --with-token

# Test
gh auth status
```

**Verify:** `gh auth status` should show "Logged in to github.com". If it fails, tell the user and ask for a corrected token.

**Then ask:**
- "What GitHub username should I configure for git commits?"
- "What email should I use for git commits?"

```bash
git config --global user.name "<USERNAME>"
git config --global user.email "<EMAIL>"
```

**Important rule to save:** "All git commits are authored as the user — never as the agent or OpenClaw."

## Step 3: Cloudflare Tunnel

**Ask the user:**
- "Do you want to set up Cloudflare Tunnel for custom domain routing? (yes/skip)"

If yes:
- "Please provide your Cloudflare API Token. It needs permissions: `Zone:DNS:Edit`, `Account:Cloudflare Tunnel:Edit`, `Zone:Zone:Read`. Create one at https://dash.cloudflare.com/profile/api-tokens"

**Test the token:**

```bash
# Test API token
curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer <CF_TOKEN>" | jq '.success'
```

Must return `true`. If not, tell user the token is invalid.

**Then ask:**
- "What domain do you want to use? (e.g., example.com)"

**Look up zone ID:**

```bash
curl -s "https://api.cloudflare.com/client/v4/zones?name=<DOMAIN>" \
  -H "Authorization: Bearer <CF_TOKEN>" | jq -r '.result[0].id'
```

If null, the token doesn't have access to that domain — inform the user.

**List existing tunnels:**

```bash
# Get account ID
ACCOUNT_ID=$(curl -s "https://api.cloudflare.com/client/v4/accounts" \
  -H "Authorization: Bearer <CF_TOKEN>" | jq -r '.result[0].id')

# List tunnels
curl -s "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel" \
  -H "Authorization: Bearer <CF_TOKEN>" | jq '.result[] | {id, name, status}'
```

Tell the user what tunnels exist. Ask if they want to use an existing one or create a new one.

**Save to TOOLS.md:**
```
### Cloudflare
- API Token: (reference only — stored in env)
- Zone ID: <ZONE_ID>
- Account ID: <ACCOUNT_ID>
- Domain: <DOMAIN>
- Tunnel ID: <TUNNEL_ID>
```

## Step 4: Coolify Integration (Optional)

**Ask:** "Do you have a Coolify instance? If yes, provide the URL and API token. (or skip)"

If yes:
- "Coolify URL (e.g., https://coolify.yourdomain.com):"
- "Coolify API Token (Settings → API Tokens in Coolify dashboard):"

**Test:**

```bash
curl -s "<COOLIFY_URL>/api/v1/servers" \
  -H "Authorization: Bearer <COOLIFY_TOKEN>" \
  -H "Content-Type: application/json" | jq '.[0].uuid'
```

Should return a server UUID. If unauthorized, token is wrong.

**Discover infrastructure:**

```bash
# Get server UUID
SERVER_UUID=$(curl -s "<COOLIFY_URL>/api/v1/servers" \
  -H "Authorization: Bearer <COOLIFY_TOKEN>" | jq -r '.[0].uuid')

# List projects
curl -s "<COOLIFY_URL>/api/v1/projects" \
  -H "Authorization: Bearer <COOLIFY_TOKEN>" | jq '.[] | {uuid, name}'

# Check GitHub app connection
curl -s "<COOLIFY_URL>/api/v1/security/keys" \
  -H "Authorization: Bearer <COOLIFY_TOKEN>" | jq '.[].name'
```

Tell the user what was found. Save server UUID, project UUIDs to TOOLS.md.

**Required API token permissions:** The Coolify API token needs `root` access (created from admin account). There are no granular scopes — it's all-or-nothing in Coolify.

## Step 5: LLM Proxy (Optional)

**Ask:** "Do you have an OpenAI-compatible LLM proxy? This lets sub-agents use models at lower cost. Provide the base URL and API key, or skip."

If yes:
- "Proxy base URL (e.g., https://llm.yourdomain.com/v1):"
- "API key:"

**Test:**

```bash
curl -s "<PROXY_URL>/models" \
  -H "Authorization: Bearer <API_KEY>" | jq '.data | length'
```

Should return a number > 0. If it fails, tell the user.

**Ask:** "What models do you want available for sub-agents? Common choices: claude-sonnet-4-6, gpt-4.1-mini, deepseek-chat"

Then generate `~/.openclaw/config.yaml` model entries (see Step 7).

## Step 6: ClawHub Skills

Install recommended skills:

```bash
clawhub install git-essentials
clawhub install docker-essentials
clawhub install github-cli
clawhub install cloudflare-agent-tunnel
clawhub install dev-serve
clawhub install react-expert
clawhub install tailwindcss
clawhub install vite
clawhub install coolify-deploy
clawhub install vercel-deploy
clawhub install security-auditor
```

Tell the user which ones installed successfully.

**Ask:** "Want to install additional skills? Check https://clawhub.com for the full catalog."

## Step 7: Custom Models Config

If an LLM proxy was configured in Step 5, write `~/.openclaw/config.yaml`:

```yaml
models:
  mode: merge
  providers:
    custom-llm-proxy:
      models:
        - id: <MODEL_ID>
          name: "<MODEL_ID> (LLM Proxy)"
          api: openai-completions
          reasoning: false
          input: [text, image]
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
          contextWindow: 200000
          maxTokens: 8192
        # Repeat for each model the user chose

agents:
  defaults:
    subagents:
      model: "custom-llm-proxy/<PRIMARY_MODEL>"
```

**Important:** After writing config.yaml, restart the gateway:
```bash
openclaw gateway restart
```

Test that models are available:
```bash
openclaw status
```

## Step 8: Workspace Files

Generate starter workspace files. **Ask the user for personalization:**

- "What should I call you? (name for USER.md)"
- "What timezone are you in? (e.g., America/New_York)"
- "Any preferences I should know about? (e.g., preferred stack, communication style)"

**Create these files in the workspace:**

### USER.md
```markdown
# USER.md - About Your Human
- **Name:** <NAME>
- **Timezone:** <TIMEZONE>
- **Notes:** <PREFERENCES>
```

### TOOLS.md
Compile all credentials and infrastructure notes from previous steps (reference only, no raw keys in files that get committed):

```markdown
# TOOLS.md - Local Notes

### GitHub
- Account: <USERNAME>
- Auth: gh CLI with PAT
- Git identity: <USERNAME> / <EMAIL>

### Cloudflare
- Domain: <DOMAIN>
- Zone ID: <ZONE_ID>
- Account ID: <ACCOUNT_ID>
- Tunnel ID: <TUNNEL_ID>

### Coolify
- URL: <COOLIFY_URL>
- Server UUID: <SERVER_UUID>
```

### IDENTITY.md
Ask: "What name and personality should your agent have?"

### SOUL.md and AGENTS.md
Copy the templates from `templates/` in this repo.

## Validation Checklist

After all steps, run a final check:

```bash
echo "=== Validation ==="
echo -n "gh: " && gh auth status 2>&1 | grep -q "Logged in" && echo "✅" || echo "❌"
echo -n "git: " && git config --global user.name > /dev/null && echo "✅" || echo "❌"
echo -n "cloudflared: " && command -v cloudflared > /dev/null && echo "✅" || echo "❌"
echo -n "node: " && node --version > /dev/null && echo "✅" || echo "❌"
echo -n "playwright: " && npx playwright --version > /dev/null 2>&1 && echo "✅" || echo "❌"
echo -n "clawhub: " && command -v clawhub > /dev/null && echo "✅" || echo "❌"
echo -n "gateway: " && openclaw gateway status 2>&1 | grep -q "running\|active" && echo "✅" || echo "❌"
```

Show results to user. For any ❌, offer to retry that step.

## Rules

- **NEVER** hardcode any API keys, tokens, passwords, or personal info
- **ALWAYS** test credentials before saving them
- **ALWAYS** ask the user before running destructive commands
- **ALWAYS** create repos as PRIVATE
- **NEVER** commit secrets to git — use .env files (gitignored) or reference-only in TOOLS.md
- If a step fails, explain what went wrong and offer to retry or skip
- Save progress — if the user disconnects, they can resume from where they left off
