#!/usr/bin/env bash
# OpenClaw Bootstrap — Validation Script
# Run after setup to verify everything is configured correctly.

set -euo pipefail

PASS=0
FAIL=0
SKIP=0

check() {
  local name="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "  ✅ $name"
    ((PASS++))
  else
    echo "  ❌ $name"
    ((FAIL++))
  fi
}

optional() {
  local name="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "  ✅ $name"
    ((PASS++))
  else
    echo "  ⏭️  $name (optional)"
    ((SKIP++))
  fi
}

skip() {
  echo "  ⏭️  $1 (skipped)"
  ((SKIP++))
}

echo ""
echo "🔍 OpenClaw Bootstrap Validation"
echo "================================"
echo ""

echo "Prerequisites:"
check "openclaw installed" command -v openclaw
check "gateway running" bash -c 'openclaw gateway status 2>&1 | grep -qiE "running|active"'
check "openclaw.json exists" test -f "$HOME/.openclaw/openclaw.json"

echo ""
echo "System Packages:"
check "gh CLI installed" command -v gh
check "cloudflared installed" command -v cloudflared
check "node installed" command -v node
check "jq installed" command -v jq
check "curl installed" command -v curl
check "clawhub installed" command -v clawhub
optional "docker installed" command -v docker
optional "nmap installed" command -v nmap
optional "nikto installed" command -v nikto
optional "sqlmap installed" command -v sqlmap
optional "lighthouse installed" command -v lighthouse

echo ""
echo "GitHub:"
if command -v gh > /dev/null 2>&1; then
  check "gh authenticated" gh auth status
  check "git user.name set" git config --global user.name
  check "git user.email set" git config --global user.email
else
  skip "gh authentication (gh not installed)"
fi

echo ""
echo "Cloudflare:"
if [ -n "${CF_API_TOKEN:-}" ]; then
  check "CF token valid" bash -c 'curl -sf "https://api.cloudflare.com/client/v4/user/tokens/verify" -H "Authorization: Bearer $CF_API_TOKEN" | jq -e ".success"'
else
  skip "Cloudflare token (CF_API_TOKEN not set)"
fi

echo ""
echo "Coolify:"
if [ -n "${COOLIFY_URL:-}" ] && [ -n "${COOLIFY_TOKEN:-}" ]; then
  check "Coolify API reachable" bash -c 'curl -sf "$COOLIFY_URL/api/v1/servers" -H "Authorization: Bearer $COOLIFY_TOKEN" | jq -e ".[0].uuid"'
else
  skip "Coolify API (COOLIFY_URL/COOLIFY_TOKEN not set)"
fi

echo ""
echo "LLM Proxy:"
if [ -n "${LLM_PROXY_URL:-}" ] && [ -n "${LLM_PROXY_KEY:-}" ]; then
  check "LLM Proxy reachable" bash -c 'curl -sf "$LLM_PROXY_URL/models" -H "Authorization: Bearer $LLM_PROXY_KEY" | jq -e ".data | length > 0"'
else
  skip "LLM Proxy (LLM_PROXY_URL/LLM_PROXY_KEY not set)"
fi

echo ""
echo "Browser:"
optional "playwright chromium" bash -c 'npx playwright --version'
if [ -f "$HOME/.openclaw/openclaw.json" ]; then
  optional "browser enabled in config" bash -c 'jq -e ".browser.enabled == true" "$HOME/.openclaw/openclaw.json"'
fi

echo ""
echo "OpenClaw Config:"
if [ -f "$HOME/.openclaw/config.yaml" ]; then
  check "config.yaml exists" test -f "$HOME/.openclaw/config.yaml"
else
  skip "config.yaml (no custom models configured)"
fi

echo ""
echo "Agents:"
if [ -f "$HOME/.openclaw/openclaw.json" ]; then
  AGENT_COUNT=$(jq '.agents.list // [] | length' "$HOME/.openclaw/openclaw.json" 2>/dev/null || echo "0")
  if [ "$AGENT_COUNT" -gt 1 ]; then
    echo "  ✅ $AGENT_COUNT agents registered in openclaw.json"
    ((PASS++))
    # Check each expected agent
    for agent in coder architect reviewer tester pentester researcher; do
      if jq -e ".agents.list[] | select(.id == \"$agent\")" "$HOME/.openclaw/openclaw.json" > /dev/null 2>&1; then
        echo "    ✅ $agent"
      else
        echo "    ❌ $agent (not registered)"
        ((FAIL++))
      fi
    done
  else
    echo "  ⏭️  No sub-agents registered (optional)"
    ((SKIP++))
  fi
fi

WS="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"

echo ""
echo "Agent Templates:"
if [ -d "$WS/agents" ]; then
  for tmpl in architect.md coder.md reviewer.md tester.md pentester.md researcher.md; do
    if [ -f "$WS/agents/$tmpl" ]; then
      echo "  ✅ agents/$tmpl"
      ((PASS++))
    else
      echo "  ❌ agents/$tmpl missing"
      ((FAIL++))
    fi
  done
else
  skip "Agent templates directory (agents/)"
fi

echo ""
echo "Workspace Files:"
for f in SOUL.md USER.md TOOLS.md AGENTS.md IDENTITY.md MEMORY.md; do
  if [ -f "$WS/$f" ]; then
    echo "  ✅ $f"
    ((PASS++))
  else
    echo "  ❌ $f missing"
    ((FAIL++))
  fi
done
optional "memory/ directory" test -d "$WS/memory"

echo ""
echo "SSH:"
if [ -f "$HOME/.ssh/config" ]; then
  HOST_COUNT=$(grep -c "^Host " "$HOME/.ssh/config" 2>/dev/null || echo "0")
  echo "  ✅ SSH config exists ($HOST_COUNT hosts)"
  ((PASS++))
else
  skip "SSH config (no remote hosts configured)"
fi

echo ""
echo "Docker:"
if command -v docker > /dev/null 2>&1; then
  optional "Docker daemon running" docker info
fi

echo ""
echo "================================"
echo "Results: ✅ $PASS passed | ❌ $FAIL failed | ⏭️  $SKIP skipped"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "⚠️  Some checks failed. Re-run the bootstrap or fix manually."
  exit 1
else
  echo "🎉 All checks passed! Your OpenClaw instance is ready."
  exit 0
fi
