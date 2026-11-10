---
description: Hand a coding task to an Engine Box agent run and follow it to the end
argument-hint: "<what to build or fix> [in <project/repository>]"
---

Run this task on Engine Box: `$ARGUMENTS`. Follow the `enginebox` skill.

1. Call `grants()` on the `enginebox` MCP server. If the server is missing or answers unauthorized,
   tell the person to connect Engine Box first (Grok Bot: Connect apps; Claude Code: `/mcp`) and stop.
2. Pick the pool from the grants (ask only if several fit and the task does not say). If a repository
   is named, check it with `repository_get`. Pick a branch `grok/<task-slug>`.
3. Write a complete prompt with acceptance criteria and the skill's branch instruction, then
   `pool_agent_launch` with `repository`, `branch` and an idempotency key.
4. Poll `pool_agent_run` until the run ends, then follow its `preview` as the skill says (a
   `not-configured` preview gets one follow-up run that adds the config).
5. Report what changed, the branch, the preview URL and the evidence. Merge only if the person says so.
