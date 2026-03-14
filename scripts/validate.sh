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

skip() {
  echo "  ⏭️  $1 (skipped)"
  ((SKIP++))
}

echo ""
echo "🔍 OpenClaw Bootstrap Validation"
echo "================================"
echo ""

echo "System Packages:"
check "gh CLI installed" command -v gh
check "cloudflared installed" command -v cloudflared
check "node installed" command -v node
check "jq installed" command -v jq
check "curl installed" command -v curl
check "clawhub installed" command -v clawhub

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
echo "OpenClaw:"
check "openclaw installed" command -v openclaw
check "gateway running" bash -c 'openclaw gateway status 2>&1 | grep -qiE "running|active"'
check "playwright chromium" bash -c 'npx playwright --version'

echo ""
echo "Workspace Files:"
WS="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
[ -f "$WS/SOUL.md" ] && check "SOUL.md exists" test -f "$WS/SOUL.md" || skip "SOUL.md"
[ -f "$WS/USER.md" ] && check "USER.md exists" test -f "$WS/USER.md" || skip "USER.md"
[ -f "$WS/TOOLS.md" ] && check "TOOLS.md exists" test -f "$WS/TOOLS.md" || skip "TOOLS.md"
[ -f "$WS/AGENTS.md" ] && check "AGENTS.md exists" test -f "$WS/AGENTS.md" || skip "AGENTS.md"
[ -f "$WS/IDENTITY.md" ] && check "IDENTITY.md exists" test -f "$WS/IDENTITY.md" || skip "IDENTITY.md"

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
