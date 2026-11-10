# Engine Box plugin

Lets your AI assistant run coding agents on [Engine Box](https://enginebox.coopcollective.dev): it hands
a task and a repository to a Codex, Claude or Grok Build run on a cloud workspace, follows the run to the
end and reports what changed. It connects to the hosted Engine Box MCP server over HTTP with OAuth, so
there is no token in this repository or on your machine; you sign in once and choose, on Engine Box's
consent screen, which pools and repository projects the assistant may use.

The assistant can launch, check and cancel runs, list its runs, read provider usage, and list or
create hosted repositories. It **cannot** create or delete machines, templates or storage: fleet
administration is not exposed over this connection.

## Install

**Grok Bot:** Connect apps → Add → install from GitHub `coop-collective/enginebox-plugin` (it is a
Cursor-format plugin: `.cursor-plugin/plugin.json`, `mcp.json`, `skills/`, `assets/logo.svg`), or add a
custom MCP server `https://enginebox.coopcollective.dev/mcp`. Sign in with your Engine Box email code,
choose the pools and projects, and approve.

**Grok CLI**

```bash
grok plugin install coop-collective/enginebox-plugin --trust
```

Then `/mcps` and sign in to `enginebox`.

**Claude Code**

```bash
claude plugin marketplace add coop-collective/enginebox-plugin
claude plugin install enginebox@enginebox
claude mcp login plugin:enginebox:enginebox   # or /mcp inside a session
```

**Codex**

```bash
codex plugin marketplace add coop-collective/enginebox-plugin
codex plugin add enginebox@enginebox
codex mcp login enginebox
```

**Cursor:** install this repository as a plugin, or add
`{"mcpServers":{"enginebox":{"url":"https://enginebox.coopcollective.dev/mcp"}}}` to `~/.cursor/mcp.json`.

## Use

Ask for the work: "fix the failing checkout test in alpha/shop and push a branch", or
`/enginebox:build <task>`. The `enginebox` skill teaches the assistant to check its grants, write a
complete prompt with acceptance criteria, launch on a branch with an idempotency key, poll the run, and
report the branch, the evidence and the branch's live preview URL. Engine Box starts that preview by
itself when the run succeeds (from the branch's `.enginebox/config.json` `dev` section; if it is
missing, the assistant has a follow-up run add it). Nothing is merged until you say "merge it".

## Tools (server `enginebox`)

`grants`, `pool_agent_launch`, `pool_agent_run`, `pool_agent_cancel`, `agent_launch`, `agent_run`,
`agent_cancel`, `agent_runs`, `repository_list`, `repository_get`, `repository_create`,
`usage_accounts`. See [the skill](skills/enginebox/SKILL.md) for arguments and errors.

## Disconnect

Engine Box dashboard → MCP → Connected apps → Disconnect. The assistant's token stops working at once.

## Self-hosted Engine Box

Point the MCP URL in `mcp.json` (Grok Bot, Cursor), `.mcp.json` (Claude Code, Grok CLI) and
`.codex-mcp.json` (Codex) at `https://<your-dashboard-origin>/mcp`. OAuth must be enabled on that
dashboard (`ENGINEBOX_OAUTH_STATE_DIR`).

## Develop

`sh test/check.sh` checks that the manifests parse and agree. Needs `jq`.

## License

[MIT](LICENSE).
