# Agent Squad

Specialized sub-agents for building applications and websites. Spawned from the main agent session via `sessions_spawn`.

## Agents

| Role | File | Recommended Model | Purpose |
|------|------|-------------------|---------|
| **Architect** | `architect.md` | opus-tier (heavy reasoning) | Plans projects, designs architecture, breaks down tasks |
| **Coder** | `coder.md` | sonnet-tier (fast coding) | Implements code, commits & pushes to GitHub |
| **Reviewer** | `reviewer.md` | sonnet-tier | Code review: catches bugs, security issues, bad patterns |
| **Tester** | `tester.md` | sonnet-tier | Blind UX testing via browser, reports bugs & friction |
| **Pentester** | `pentester.md` | sonnet-tier | Security testing: OWASP Top 10, injection, auth bypass |
| **Researcher** | `researcher.md` | mini-tier (cheap) | Market research, competitors, user complaints, pricing |

## Workflow

A typical build pipeline looks like:

```
1. Researcher  → Market research, competitor analysis
2. Architect   → System design, task breakdown
3. Coder       → Implementation (multiple rounds)
4. Reviewer    → Code review after each round
5. Tester      → End-to-end UX testing on deployed app
6. Pentester   → Security audit before launch
```

The main agent orchestrates this pipeline, spawning each agent as needed and feeding results between them.

## Spawning Agents

Each agent is spawned via `sessions_spawn` with its role file loaded as the task prefix:

```
sessions_spawn:
  label: <role>
  model: <provider>/<model>
  task: |
    Read agents/<role>.md for your role instructions.

    [SPECIFIC TASK HERE]
  mode: run
  runTimeoutSeconds: 600
```

### Model Selection Guide

- **Architect:** Use your heaviest model — it's planning, not bulk coding
- **Coder:** Use a fast, capable coding model (sonnet-tier). For ACP (Claude Code), use `runtime: acp`
- **Reviewer:** Same tier as Coder — needs to understand the code deeply
- **Tester:** Needs browser access — use a model that works well with tool calls
- **Pentester:** Same tier as Coder — needs creativity for finding exploits
- **Researcher:** Use a cheap model — it's mostly web search and synthesis

## Customization

These templates use `{{PLACEHOLDER}}` values that get filled in during bootstrap setup:
- `{{GIT_USERNAME}}` / `{{GIT_EMAIL}}` — from Step 2 (GitHub setup)
- `{{DOMAIN}}` — from Step 3 (Cloudflare setup)
- `{{DEPLOYMENT_PLATFORM}}` — from Step 4 (Coolify or your platform)
- `{{LLM_PROXY_URL}}` — from Step 5 (LLM proxy setup)
- `{{GITHUB_USERNAME}}` — from Step 2

The bootstrap SKILL.md handles replacing these with your actual values.
