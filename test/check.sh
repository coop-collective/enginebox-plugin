#!/bin/sh
# Offline checks: every manifest parses, they agree, and every client points at the same MCP URL.
set -eu
cd "$(dirname "$0")/.."
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'ok: %s\n' "$*"; }

for f in .cursor-plugin/plugin.json .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json mcp.json .mcp.json .codex-mcp.json package.json; do
  jq -e . "$f" >/dev/null || fail "$f is not valid JSON"
done
ok "JSON files parse"

url=https://enginebox.coopcollective.dev/mcp
for f in mcp.json .mcp.json .codex-mcp.json; do
  [ "$(jq -r '.mcpServers.enginebox.url' "$f")" = "$url" ] || fail "$f MCP url"
done
[ "$(jq -r '.mcpServers' .codex-plugin/plugin.json)" = ./.codex-mcp.json ] || fail "codex manifest must point at .codex-mcp.json"
for k in name version license repository; do
  a=$(jq -r ".$k" .cursor-plugin/plugin.json)
  for m in .claude-plugin/plugin.json .codex-plugin/plugin.json; do
    [ "$(jq -r ".$k" "$m")" = "$a" ] || fail "$m disagrees on $k"
  done
done
[ -f "$(jq -r .logo .cursor-plugin/plugin.json)" ] || fail "logo missing"
[ -f skills/enginebox/SKILL.md ] || fail "skill missing"
head -1 skills/enginebox/SKILL.md | grep -qx -- '---' || fail "skill frontmatter"
ok "manifests agree"

# The skill names exactly the tools the server offers.
for t in grants pool_agent_launch pool_agent_run pool_agent_cancel agent_launch agent_run agent_cancel agent_runs repository_list repository_get repository_create usage_accounts; do
  grep -q "\`$t" skills/enginebox/SKILL.md || fail "skill does not mention $t"
done
ok "skill covers every tool"
