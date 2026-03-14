# OpenClaw Bootstrap Skill

You are guiding a user through setting up a fresh OpenClaw instance with full infrastructure integration. This is an interactive setup — prompt the user in chat for every secret/credential. NEVER hardcode or assume any API keys, domains, usernames, or personal information.

## Overview

Tell the user upfront what you'll set up:

```
🚀 OpenClaw Bootstrap — Full Environment Setup

I'll walk you through setting up:
1. Environment detection (OS, arch, package manager)
2. System packages (gh, cloudflared, jq, playwright)
3. GitHub CLI authentication + git identity
4. Cloudflare Tunnel (connect your domain)
5. Coolify PaaS integration (optional)
6. LLM Proxy for sub-agents (optional)
7. ClawHub skills installation
8. Custom model config for sub-agents
9. Browser automation (Playwright)
10. Workspace files (TOOLS.md, USER.md, MEMORY.md, etc.)
11. Agent pipeline (Architect, Coder, Reviewer, Tester, Pentester, Researcher)

Each step tests credentials before saving. You can skip optional steps.
Ready? Let's go.
```

## Step 1: Environment Detection

Before installing anything, investigate the system you're running on. This determines which commands to use throughout the entire setup.

```bash
echo "=== Environment Detection ==="

# OS and distro
echo -n "OS: " && uname -s
echo -n "Kernel: " && uname -r
echo -n "Arch: " && uname -m

# Detect distro family
if [ -f /etc/os-release ]; then
  . /etc/os-release
  echo "Distro: $NAME $VERSION_ID ($ID)"
  echo "ID_LIKE: ${ID_LIKE:-$ID}"
else
  echo "Distro: Unknown (no /etc/os-release)"
fi

# Detect package manager
echo -n "Package manager: "
if command -v apt-get > /dev/null 2>&1; then
  echo "apt (Debian/Ubuntu)"
  PKG_MANAGER="apt"
elif command -v pacman > /dev/null 2>&1; then
  echo "pacman (Arch)"
  PKG_MANAGER="arch"
elif command -v dnf > /dev/null 2>&1; then
  echo "dnf (Fedora/RHEL)"
  PKG_MANAGER="dnf"
elif command -v yum > /dev/null 2>&1; then
  echo "yum (CentOS/RHEL)"
  PKG_MANAGER="yum"
elif command -v apk > /dev/null 2>&1; then
  echo "apk (Alpine)"
  PKG_MANAGER="apk"
else
  echo "Unknown"
  PKG_MANAGER="unknown"
fi

# Container detection
echo -n "Container: "
if [ -f /.dockerenv ]; then
  echo "Docker"
elif grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
  echo "LXC"
elif systemd-detect-virt --quiet 2>/dev/null; then
  echo "$(systemd-detect-virt)"
else
  echo "bare metal / unknown"
fi

# Check available disk space
echo -n "Disk free: " && df -h / | awk 'NR==2 {print $4}'

# Check RAM
echo -n "RAM: " && free -h | awk '/^Mem:/ {print $2}'

# Check if running as root
echo -n "User: " && whoami
echo -n "Sudo: " && (command -v sudo > /dev/null && echo "available" || echo "not available")

# Check what's already installed
echo ""
echo "=== Already Installed ==="
for cmd in gh cloudflared node npm jq curl git python3 docker clawhub; do
  if command -v "$cmd" > /dev/null 2>&1; then
    VERSION=$($cmd --version 2>&1 | head -1)
    echo "  ✅ $cmd — $VERSION"
  else
    echo "  ❌ $cmd — not installed"
  fi
done
```

**Save the results.** Tell the user what you found and note the distro family. Write it to a temporary reference:

```bash
# Save for use throughout setup
cat > /tmp/openclaw-bootstrap-env.sh << 'EOF'
# Detected during OpenClaw bootstrap
DISTRO_FAMILY="<apt|arch|dnf|yum|apk>"
DISTRO_NAME="<e.g., Ubuntu 24.04, Arch Linux, Debian 12>"
ARCH="<x86_64|aarch64>"
PKG_MANAGER="<apt|pacman|dnf|yum|apk>"
IS_CONTAINER="<docker|lxc|none>"
EOF
```

**Tell the user:**
```
🔍 Environment detected:
  OS: <distro> (<arch>)
  Package manager: <pkg_manager>
  Running in: <container type or bare metal>
  RAM: <amount> | Disk free: <amount>

  Already installed: <list>
  Need to install: <list>

This guide defaults to Debian/Ubuntu (apt) commands.
I'll adapt all commands for your system automatically.
```

**⚠️ Important:** Remember the detected `PKG_MANAGER` for ALL subsequent steps. When the guide shows `apt-get install`, adapt:
- **Debian/Ubuntu:** `apt-get install -y <package>`
- **Arch Linux:** `pacman -S --noconfirm <package>` (package names may differ!)
- **Fedora/RHEL:** `dnf install -y <package>`
- **Alpine:** `apk add <package>`

Common package name differences:

| Tool | Debian/Ubuntu | Arch Linux | Fedora/RHEL |
|------|--------------|------------|-------------|
| jq | `jq` | `jq` | `jq` |
| curl | `curl` | `curl` | `curl` |
| git | `git` | `git` | `git` |
| GitHub CLI | `gh` (from repo) | `github-cli` (community) | `gh` (from repo) |
| python3 | `python3` | `python` | `python3` |

## Step 2: System Packages

Install required CLI tools. Check each first, only install what's missing. **Use the package manager detected in Step 1.**

### Debian/Ubuntu (apt)

```bash
apt-get update

# GitHub CLI
(command -v gh > /dev/null) || {
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  apt-get update && apt-get install -y gh
}

# Cloudflared
(command -v cloudflared > /dev/null) || {
  ARCH=$(dpkg --print-architecture)
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb" \
    -o /tmp/cloudflared.deb
  dpkg -i /tmp/cloudflared.deb
  rm /tmp/cloudflared.deb
}

# Other essentials
apt-get install -y jq curl
```

### Arch Linux (pacman)

```bash
pacman -Syu --noconfirm

# GitHub CLI (from community repo)
(command -v gh > /dev/null) || pacman -S --noconfirm github-cli

# Cloudflared (from AUR — needs an AUR helper like yay/paru, or manual build)
(command -v cloudflared > /dev/null) || {
  if command -v yay > /dev/null; then
    yay -S --noconfirm cloudflared-bin
  elif command -v paru > /dev/null; then
    paru -S --noconfirm cloudflared-bin
  else
    # Direct binary install as fallback
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64) CF_ARCH="amd64" ;;
      aarch64) CF_ARCH="arm64" ;;
      *) CF_ARCH="amd64" ;;
    esac
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" \
      -o /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
  fi
}

# Other essentials
pacman -S --noconfirm jq curl
```

### Fedora/RHEL (dnf)

```bash
dnf check-update || true

# GitHub CLI
(command -v gh > /dev/null) || {
  dnf install -y 'dnf-command(config-manager)'
  dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
  dnf install -y gh
}

# Cloudflared (direct binary)
(command -v cloudflared > /dev/null) || {
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) CF_ARCH="amd64" ;;
    aarch64) CF_ARCH="arm64" ;;
    *) CF_ARCH="amd64" ;;
  esac
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}.rpm" \
    -o /tmp/cloudflared.rpm
  dnf install -y /tmp/cloudflared.rpm
  rm /tmp/cloudflared.rpm
}

# Other essentials
dnf install -y jq curl
```

### All platforms — verify

After installing, verify everything:

```bash
echo "=== Installed Versions ==="
gh --version 2>/dev/null || echo "❌ gh not installed"
cloudflared --version 2>/dev/null || echo "❌ cloudflared not installed"
jq --version 2>/dev/null || echo "❌ jq not installed"
node --version 2>/dev/null || echo "❌ node not installed"
```

Tell the user what was installed and the versions of each tool.

## Step 3: GitHub CLI

**Ask the user:**
- "Please provide your GitHub Personal Access Token (PAT)."
- "You can create a **fine-grained PAT** (recommended) at: https://github.com/settings/personal-access-tokens/new"
- "Or a **classic PAT** at: https://github.com/settings/tokens/new"

**Required permissions:**

For a **fine-grained PAT** (recommended):
- Repository access: All repositories (or select repos)
- Permissions: Contents (Read & Write), Metadata (Read), Pull requests (Read & Write), Actions (Read), Administration (Read & Write — needed for creating repos)

For a **classic PAT**:
- `repo` (full control of private repositories)
- `workflow` (update GitHub Actions workflows)
- `read:org` (read org membership — only if in an org)

**After receiving the token:**

```bash
# Authenticate
echo "<TOKEN>" | gh auth login --with-token

# Test authentication
gh auth status
```

**Verify:** Output must show "Logged in to github.com". If it fails, tell the user the token is invalid and ask for a corrected one.

**Test repo creation permissions:**

```bash
# Try creating and immediately deleting a test repo
gh repo create test-openclaw-bootstrap-check --private --confirm 2>/dev/null && \
  gh repo delete test-openclaw-bootstrap-check --yes 2>/dev/null && \
  echo "✅ Repo creation works" || \
  echo "⚠️ Repo creation failed — token may need 'Administration' permission"
```

**Then ask:**
- "What GitHub username should I configure for git commits?"
- "What email should I use for git commits? (Tip: use your GitHub noreply email if you want privacy: `username@users.noreply.github.com`)"

```bash
git config --global user.name "<USERNAME>"
git config --global user.email "<EMAIL>"
```

**Save this rule to AGENTS.md:** "All git commits are authored as the user — never as the agent or OpenClaw."

## Step 4: Cloudflare Tunnel (Optional)

**Ask:** "Do you want to set up Cloudflare for custom domain routing? (yes/skip)"

If yes:

**Ask:** "Please provide your Cloudflare API Token. Create one at https://dash.cloudflare.com/profile/api-tokens with these permissions:"
- `Zone : DNS : Edit`
- `Zone : Zone : Read`
- `Account : Cloudflare Tunnel : Edit`
- `Account : Cloudflare Tunnel : Read`

**Test the token:**

```bash
CF_TOKEN="<TOKEN>"

# Verify token is valid
RESULT=$(curl -sf "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CF_TOKEN" | jq -r '.success')

if [ "$RESULT" = "true" ]; then
  echo "✅ Token is valid"
else
  echo "❌ Token is invalid"
fi
```

If invalid, tell the user and ask for a corrected token.

**Ask:** "What domain do you want to use? (e.g., example.com)"

**Look up zone and account:**

```bash
DOMAIN="<DOMAIN>"

# Get Zone ID
ZONE_ID=$(curl -sf "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
  -H "Authorization: Bearer $CF_TOKEN" | jq -r '.result[0].id // empty')

if [ -z "$ZONE_ID" ]; then
  echo "❌ No zone found for $DOMAIN — token may not have access to this domain"
else
  echo "✅ Zone ID: $ZONE_ID"
fi

# Get Account ID
ACCOUNT_ID=$(curl -sf "https://api.cloudflare.com/client/v4/zones/$ZONE_ID" \
  -H "Authorization: Bearer $CF_TOKEN" | jq -r '.result.account.id')
echo "Account ID: $ACCOUNT_ID"
```

**List existing tunnels:**

```bash
# List active (non-deleted) tunnels
curl -sf "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel?is_deleted=false" \
  -H "Authorization: Bearer $CF_TOKEN" | jq '.result[] | {id, name, status}'
```

Tell the user what tunnels exist. Ask: "Use an existing tunnel, or create a new one?"

**If creating a new tunnel:**

```bash
TUNNEL_NAME="openclaw-tunnel"

# Create tunnel
TUNNEL_RESULT=$(curl -sf -X POST \
  "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$TUNNEL_NAME\", \"tunnel_secret\": \"$(openssl rand -base64 32)\"}")

TUNNEL_ID=$(echo "$TUNNEL_RESULT" | jq -r '.result.id')
TUNNEL_TOKEN=$(echo "$TUNNEL_RESULT" | jq -r '.result.token')

echo "✅ Tunnel created: $TUNNEL_ID"

# Install and run the connector
cloudflared service install "$TUNNEL_TOKEN"
systemctl enable cloudflared
systemctl start cloudflared
```

**List existing subdomains (DNS CNAMEs pointing to the tunnel):**

```bash
curl -sf "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=CNAME" \
  -H "Authorization: Bearer $CF_TOKEN" | jq -r '.result[] | .name'
```

Tell the user which subdomains are already taken.

**Save to TOOLS.md:**
```markdown
### Cloudflare
- API Token: (stored in environment, not in files)
- Zone ID: <ZONE_ID>
- Account ID: <ACCOUNT_ID>
- Domain: <DOMAIN>
- Tunnel ID: <TUNNEL_ID>
- Taken subdomains: <list>
```

## Step 5: Coolify Integration (Optional)

**Ask:** "Do you have a Coolify instance for app deployments? If yes, provide the URL and API token. (or skip)"
- "Coolify URL (e.g., https://coolify.yourdomain.com):"
- "Coolify API Token — create one in Coolify under Settings → API Tokens. It uses your admin account's permissions (no granular scopes)."

**Test:**

```bash
COOLIFY_URL="<URL>"
COOLIFY_TOKEN="<TOKEN>"

# Test API access
RESULT=$(curl -sf "$COOLIFY_URL/api/v1/servers" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" \
  -H "Content-Type: application/json")

SERVER_UUID=$(echo "$RESULT" | jq -r '.[0].uuid // empty')

if [ -z "$SERVER_UUID" ]; then
  echo "❌ Coolify API unreachable or token invalid"
else
  echo "✅ Connected to Coolify — Server: $SERVER_UUID"
fi
```

**Discover infrastructure:**

```bash
# List projects
curl -sf "$COOLIFY_URL/api/v1/projects" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" | jq '.[] | {uuid, name}'

# List running applications
curl -sf "$COOLIFY_URL/api/v1/applications" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" | jq '.[] | {uuid, name, fqdn, status}'

# List databases
curl -sf "$COOLIFY_URL/api/v1/databases" \
  -H "Authorization: Bearer $COOLIFY_TOKEN" | jq '.[] | {uuid, name, type}'
```

Tell the user what infrastructure was found.

**Check GitHub integration:**
- "Does Coolify have a GitHub App connected for private repo access? (Check Coolify UI → Sources → GitHub)"
- If yes, note the GitHub App UUID for future deployments

**Save to TOOLS.md:**
```markdown
### Coolify
- URL: <COOLIFY_URL>
- API Token: (stored in environment)
- Server UUID: <SERVER_UUID>
- Projects: <list>
- GitHub App UUID: <if connected>
```

**Key lesson:** When deploying apps behind Cloudflare Tunnel, set the FQDN in Coolify to `http://` (not `https://`). Traefik adds an HTTPS redirect for `https://` FQDNs, which causes redirect loops when the tunnel already handles TLS.

## Step 6: LLM Proxy (Optional)

**Ask:** "Do you have an OpenAI-compatible LLM proxy for sub-agents? This allows sub-agents to use various models through a single endpoint. Provide the base URL and API key, or skip."
- "Base URL (e.g., `https://proxy.yourdomain.com/v1` — include the `/v1` suffix):"
- "API key:"

**Test:**

```bash
PROXY_URL="<BASE_URL>"  # Should end with /v1
PROXY_KEY="<API_KEY>"

# Test model listing
MODEL_COUNT=$(curl -sf "$PROXY_URL/models" \
  -H "Authorization: Bearer $PROXY_KEY" | jq '.data | length')

if [ "$MODEL_COUNT" -gt 0 ]; then
  echo "✅ Proxy connected — $MODEL_COUNT models available"
else
  echo "❌ No models found — check URL and API key"
fi

# List available models
curl -sf "$PROXY_URL/models" \
  -H "Authorization: Bearer $PROXY_KEY" | jq -r '.data[].id' | sort
```

Show the model list to the user.

**Ask:** "Which models do you want available for sub-agents? Common choices:"
- `claude-sonnet-4-6` — fast, good for coding
- `gpt-4.1-mini` — cheap, decent quality  
- `deepseek-chat` — very cheap, good for simple tasks

## Step 7: ClawHub Skills

Install recommended skills for a well-equipped agent:

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

Run each install and report which succeeded. Some may not exist yet on ClawHub — that's fine, skip failures.

**Ask:** "Want to install additional skills? Browse https://clawhub.com for the full catalog."

## Step 8: Custom Models Config

If an LLM proxy was configured in Step 6, generate and write `~/.openclaw/config.yaml`.

**Important:** This file may already exist with other settings. Read it first, then merge — don't overwrite.

```bash
# Check for existing config
cat ~/.openclaw/config.yaml 2>/dev/null || echo "(no existing config)"
```

**Generate the models section** for each model the user chose. Example for 3 models:

```yaml
models:
  mode: merge
  providers:
    custom-llm-proxy:
      baseUrl: "<PROXY_URL>"       # e.g. https://proxy.yourdomain.com/v1
      apiKey: "<PROXY_API_KEY>"
      api: openai-completions
      models:
        - id: claude-sonnet-4-6
          name: "claude-sonnet-4-6 (LLM Proxy)"
          api: openai-completions
          reasoning: false
          input: [text, image]
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
          contextWindow: 200000
          maxTokens: 8192
        - id: gpt-4.1-mini
          name: "gpt-4.1-mini (LLM Proxy)"
          api: openai-completions
          reasoning: false
          input: [text, image]
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
          contextWindow: 128000
          maxTokens: 16384
        - id: deepseek-chat
          name: "deepseek-chat (LLM Proxy)"
          api: openai-completions
          reasoning: false
          input: [text]
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
          contextWindow: 64000
          maxTokens: 8192

agents:
  defaults:
    models:
      "custom-llm-proxy/claude-sonnet-4-6": { alias: "sonnet" }
      "custom-llm-proxy/gpt-4.1-mini": { alias: "gpt-mini" }
      "custom-llm-proxy/deepseek-chat": { alias: "deepseek" }
    subagents:
      model: "custom-llm-proxy/claude-sonnet-4-6"
```

**After writing config.yaml, restart the gateway:**

```bash
openclaw gateway restart
```

**Verify models loaded:**

```bash
openclaw gateway status
```

If the gateway fails to start, check config.yaml syntax (YAML is whitespace-sensitive).

## Step 9: Browser Automation (Playwright)

Set up Playwright for browser-based testing and automation:

```bash
# Install Playwright globally
npm install -g @playwright/test

# Install Chromium with system dependencies
npx playwright install chromium --with-deps

# Find the chromium path
CHROMIUM_PATH=$(find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1)
echo "Chromium at: $CHROMIUM_PATH"
```

**Update OpenClaw browser config** in `~/.openclaw/openclaw.json`:

Read the existing file, then update the `browser` section:

```json
{
  "browser": {
    "enabled": true,
    "executablePath": "<CHROMIUM_PATH>",
    "headless": true,
    "noSandbox": true
  }
}
```

Use `jq` to merge this into the existing openclaw.json without overwriting other settings:

```bash
OPENCLAW_JSON="$HOME/.openclaw/openclaw.json"
CHROMIUM_PATH=$(find /root/.cache/ms-playwright -name "chrome" -type f 2>/dev/null | head -1)

jq --arg path "$CHROMIUM_PATH" '.browser = {
  "enabled": true,
  "executablePath": $path,
  "headless": true,
  "noSandbox": true
}' "$OPENCLAW_JSON" > /tmp/openclaw.json.tmp && mv /tmp/openclaw.json.tmp "$OPENCLAW_JSON"
```

**Test browser works:**

```bash
# Quick test — should output page title
node -e "
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.goto('https://example.com');
  console.log('✅ Browser works — title:', await page.title());
  await browser.close();
})();
"
```

## Step 10: Workspace Files

Generate starter workspace files. **Ask the user for personalization:**

- "What should I call you? (name for USER.md)"
- "What timezone are you in? (e.g., America/New_York, Europe/London)"
- "Any preferences I should know about? (e.g., preferred tech stack, communication style)"
- "What name and personality should your agent have? (for IDENTITY.md)"

**Create these files in the workspace** (`~/.openclaw/workspace/`):

### USER.md
```markdown
# USER.md - About Your Human
- **Name:** <NAME>
- **Timezone:** <TIMEZONE>
- **Notes:** <PREFERENCES>
```

### TOOLS.md
Compile all infrastructure info discovered during setup:

```markdown
# TOOLS.md - Local Notes

### GitHub
- Account: <USERNAME>
- Auth: gh CLI with PAT (expires: <DATE>)
- Git identity: <USERNAME> / <EMAIL>
- RULE: Never attribute commits to the agent or OpenClaw

### Cloudflare
- Domain: <DOMAIN>
- Zone ID: <ZONE_ID>
- Account ID: <ACCOUNT_ID>
- Tunnel ID: <TUNNEL_ID>
- Taken subdomains: <list>

### Coolify
- URL: <COOLIFY_URL>
- Server UUID: <SERVER_UUID>
- Projects: <list>

### LLM Proxy
- URL: <PROXY_URL>
- Available models: <list>
```

**Important:** Store API tokens as references only (e.g., "stored in environment" or "in config.yaml"). Never put raw tokens in TOOLS.md if it could be committed to git.

### IDENTITY.md
```markdown
# IDENTITY.md - Who Am I?
- **Name:** <AGENT_NAME>
- **Creature:** AI assistant
- **Vibe:** <PERSONALITY>
- **Emoji:** <EMOJI>
```

### SOUL.md and AGENTS.md
Copy from `templates/` directory in this repo.

### MEMORY.md
Create an initial long-term memory file:

```markdown
# MEMORY.md - Long-Term Memory

## <TODAY'S DATE>
- Initial setup completed via openclaw-bootstrap
- Integrations configured: <list what was set up>
- User preferences: <from USER.md>
```

### memory/ directory
```bash
mkdir -p ~/.openclaw/workspace/memory
```

### HEARTBEAT.md (optional)
Ask: "Do you want periodic background checks? (email, calendar, monitoring)"

If yes, create a starter HEARTBEAT.md:
```markdown
# HEARTBEAT.md
If nothing needs attention, reply HEARTBEAT_OK.
```

## Step 11: Agent Pipeline

Set up specialized sub-agents for a full build-to-deploy workflow. These agents are spawned by the main agent to handle specific roles.

**Tell the user:**
```
🤖 Agent Pipeline Setup

I'll set up 6 specialized sub-agents that work as a team:

  Researcher  → Market research & competitor analysis
  Architect   → System design & task breakdown
  Coder       → Implementation, commits & pushes
  Reviewer    → Code review, catches bugs & security issues
  Tester      → Browser-based UX testing
  Pentester   → Security audit (OWASP Top 10)

The main agent orchestrates them — spawning each as needed
and passing results between them.
```

**Copy agent templates to workspace:**

The agent role files are in the `agents/` directory of this repo. Copy them to the workspace:

```bash
mkdir -p ~/.openclaw/workspace/agents
cp agents/architect.md ~/.openclaw/workspace/agents/
cp agents/coder.md ~/.openclaw/workspace/agents/
cp agents/reviewer.md ~/.openclaw/workspace/agents/
cp agents/tester.md ~/.openclaw/workspace/agents/
cp agents/pentester.md ~/.openclaw/workspace/agents/
cp agents/researcher.md ~/.openclaw/workspace/agents/
cp agents/README.md ~/.openclaw/workspace/agents/
```

**Replace placeholders** with actual values from earlier steps:

```bash
WORKSPACE=~/.openclaw/workspace/agents

# Replace Git identity (from Step 2)
sed -i "s|{{GIT_USERNAME}}|<USERNAME>|g" "$WORKSPACE"/*.md
sed -i "s|{{GIT_EMAIL}}|<EMAIL>|g" "$WORKSPACE"/*.md

# Replace GitHub username
sed -i "s|{{GITHUB_USERNAME}}|<USERNAME>|g" "$WORKSPACE"/*.md

# Replace domain (from Step 3, if configured)
sed -i "s|{{DOMAIN}}|<DOMAIN>|g" "$WORKSPACE"/*.md

# Replace deployment platform (from Step 4)
sed -i "s|{{DEPLOYMENT_PLATFORM}}|<PLATFORM>|g" "$WORKSPACE"/*.md

# Replace LLM proxy URL (from Step 5, if configured)
sed -i "s|{{LLM_PROXY_URL}}|<URL>|g" "$WORKSPACE"/*.md
```

**Create spawn reference** — write `agents/spawn.md` with the user's actual model config:

```markdown
# Agent Spawn Reference

## Quick spawn patterns

### Architect
sessions_spawn:
  label: architect
  model: <PROVIDER>/<HEAVY_MODEL>
  task: "Read agents/architect.md for your role.\n\n[PROJECT BRIEF]"
  mode: run
  runTimeoutSeconds: 300

### Coder (sub-agent)
sessions_spawn:
  label: coder
  model: <PROVIDER>/<CODING_MODEL>
  task: "Read agents/coder.md for your role.\n\n[TASK]"
  mode: run
  runTimeoutSeconds: 600

### Coder (via ACP / Claude Code — if available)
sessions_spawn:
  label: coder
  runtime: acp
  agentId: claude-code
  task: "Read agents/coder.md for your role.\n\n[TASK]"
  mode: run
  runTimeoutSeconds: 600

### Reviewer
sessions_spawn:
  label: reviewer
  model: <PROVIDER>/<CODING_MODEL>
  task: "Read agents/reviewer.md for your role.\n\n[REVIEW TARGET]"
  mode: run
  runTimeoutSeconds: 600

### Tester
sessions_spawn:
  label: tester
  model: <PROVIDER>/<CODING_MODEL>
  task: "Read agents/tester.md for your role.\n\nTest: [URL]\nFocus: [areas]"
  mode: run
  runTimeoutSeconds: 600

### Pentester
sessions_spawn:
  label: pentester
  model: <PROVIDER>/<CODING_MODEL>
  task: "Read agents/pentester.md for your role.\n\nTarget: [URL]\nSource: [repo]\nEndpoints: [routes]"
  mode: run
  runTimeoutSeconds: 600

### Researcher
sessions_spawn:
  label: researcher
  model: <PROVIDER>/<CHEAP_MODEL>
  task: "Read agents/researcher.md for your role.\n\nResearch: [topic]"
  mode: run
  runTimeoutSeconds: 300
```

Replace `<PROVIDER>`, `<HEAVY_MODEL>`, `<CODING_MODEL>`, and `<CHEAP_MODEL>` with the user's actual provider and model IDs from Step 8.

**Ask the user:** "Which model should each agent role use?"

Suggest based on what they configured in Step 8:
- **Architect:** Heaviest/smartest model (e.g., claude-opus, gpt-4.1)
- **Coder/Reviewer/Tester/Pentester:** Mid-tier fast model (e.g., claude-sonnet, gpt-4.1-mini)
- **Researcher:** Cheapest model (e.g., gpt-4.1-mini, deepseek-chat)

If no LLM proxy was set up, they can use their primary provider's models (e.g., `anthropic/claude-sonnet-4-6`).

**Test agent spawning** — verify one agent can start:

```bash
# Quick test: spawn researcher with a trivial task
# (The main agent would normally do this, but we verify the config works)
openclaw status  # Ensure gateway is running with models loaded
```

Tell the user the agents are ready and explain the workflow:
```
✅ Agent pipeline configured!

How it works:
1. You tell me to build something
2. I spawn Researcher for market context (if needed)
3. I spawn Architect to design the system
4. I spawn Coder to implement (multiple rounds if needed)
5. I spawn Reviewer to check the code
6. I deploy, then spawn Tester for UX verification
7. I spawn Pentester for security audit before launch

You can also ask me to spawn any agent individually.
```

## Validation Checklist

After all steps, run the validation script:

```bash
bash scripts/validate.sh
```

Or run inline:

```bash
echo "=== OpenClaw Bootstrap Validation ==="

echo -n "  gh CLI: " && command -v gh > /dev/null && echo "✅" || echo "❌"
echo -n "  gh auth: " && gh auth status 2>&1 | grep -q "Logged in" && echo "✅" || echo "❌"
echo -n "  git identity: " && git config --global user.name > /dev/null 2>&1 && echo "✅" || echo "❌"
echo -n "  cloudflared: " && command -v cloudflared > /dev/null && echo "✅" || echo "❌"
echo -n "  node: " && node --version > /dev/null 2>&1 && echo "✅" || echo "❌"
echo -n "  jq: " && command -v jq > /dev/null && echo "✅" || echo "❌"
echo -n "  playwright: " && npx playwright --version > /dev/null 2>&1 && echo "✅" || echo "❌"
echo -n "  clawhub: " && command -v clawhub > /dev/null && echo "✅" || echo "❌"
echo -n "  gateway: " && openclaw gateway status 2>&1 | grep -qiE "running|active" && echo "✅" || echo "❌"
echo -n "  SOUL.md: " && test -f ~/.openclaw/workspace/SOUL.md && echo "✅" || echo "❌"
echo -n "  USER.md: " && test -f ~/.openclaw/workspace/USER.md && echo "✅" || echo "❌"
echo -n "  TOOLS.md: " && test -f ~/.openclaw/workspace/TOOLS.md && echo "✅" || echo "❌"
echo -n "  MEMORY.md: " && test -f ~/.openclaw/workspace/MEMORY.md && echo "✅" || echo "❌"
```

Show results to user. For any ❌, offer to retry that step.

## Rules

- **NEVER** hardcode any API keys, tokens, passwords, or personal info
- **ALWAYS** test credentials before saving them
- **ALWAYS** ask the user before running destructive commands
- **ALWAYS** create repos as PRIVATE
- **NEVER** commit secrets to git — use env vars, config files (gitignored), or reference-only notes
- If a step fails, explain what went wrong and offer to retry or skip
- Each step is independent — the user can skip any optional step
- If the user disconnects, they can resume; check what's already configured before re-running steps
