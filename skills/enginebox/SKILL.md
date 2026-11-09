---
name: enginebox
description: Run coding agents on Engine Box through the hosted `enginebox` MCP server. Use when the user (or your own plan) needs code built, fixed, reviewed or investigated in a repository: launch a Codex, Claude or Cursor run on an approved pool, poll it to the end, read its result, cancel it, or list and create hosted repositories. Also use on an Engine Box tool error (unauthorized, insufficient scope, queue full). Not for creating or deleting machines, templates or storage; that is owner administration and is not available here.
---

# Engine Box

Engine Box runs the official Codex, Claude and Cursor CLIs on private cloud workspaces. You never
run code yourself: you hand a run a task and a repository, it works in a fresh checkout and pushes a
branch, and you read what it did. The MCP server is `enginebox` at
`https://enginebox.coopcollective.dev/mcp`; it signs in with OAuth, and the owner chooses on the
consent screen which pools, workspaces and repository projects this connection may use.

## Tools

| Need | Tool |
|---|---|
| What may I use? **Call first.** | `grants()`: pools (with project), workspaces, repository projects and access |
| Start work | `pool_agent_launch({pool, provider, prompt, repository?, idempotency_key, timeout_seconds?, model?, run_kind?})` |
| Follow a run | `pool_agent_run({pool, run_id})` until it ends |
| Stop a run | `pool_agent_cancel({pool, run_id})`, then poll until it ends |
| My runs (reconcile, queue position) | `agent_runs()` |
| One fixed workspace instead of a pool | `agent_launch` / `agent_run` / `agent_cancel` with `{host_id, name, ...}` |
| Repositories | `repository_list({project})`, `repository_get({project, name})`, `repository_create({project, name, description?})` |
| Subscription headroom | `usage_accounts({provider?})` |

Every tool answers `{status, body}`. `isError: true` means the controller refused or failed; read
`status` and `body.error` before doing anything else.

## How to run work

1. **`grants()`** once per session. Use only the pools and projects it lists. If it is empty or the
   pool you need is missing, tell the user to reconnect Engine Box and grant it; do not guess names.
2. **Write a complete prompt.** The agent starts cold. Include: the goal in one sentence, the
   repository and branch to start from, what "done" means as checks it can run (tests, a command,
   an HTTP check), what not to touch, and "push your work to a new branch named `<name>` and end with
   a summary of what changed and how you verified it". Acceptance criteria up front are what make a
   result trustworthy.
3. **Launch with an `idempotency_key`** such as `<task-slug>:<attempt>`. Within one sign-in token
   (access tokens renew hourly) the same key returns the existing run instead of starting another.
4. **Poll** `pool_agent_run` while the run is `queued` or `running`. Back off: about every 30
   seconds at first, then every few minutes for long runs. Report progress only when something
   changes.
5. **Read the result**: `status`, output, `failure` (`{stage, reason}`). Summarize for the user: what
   changed, the branch, the evidence, anything left undone.
6. **A finished run is not an approval to ship.** Merging, deploying and publishing stay with the
   owner's process unless the user has told you otherwise.

## Acting without asking

Engine Box is built for an agent to drive. Do not ask the user before routine steps that stay
inside the granted pools: launching a run for work they asked for, retrying a failed run once with
a better prompt, splitting a task into several runs, cancelling your own stuck run, or creating a
repository in a project granted `write`. Do ask before anything that spends beyond what was asked
(many parallel runs, runs over a few hours), and never try to reach pools or projects outside
`grants()`.

## Errors

| Answer | Meaning and what to do |
|---|---|
| 401 / tool says unauthorized | The sign-in ended or was disconnected. Ask the user to reconnect Engine Box (Grok Bot: Connect apps; Claude Code: `/mcp`). |
| 403 `insufficient_scope` | That pool, workspace or project was not granted. Use `grants()`; ask the user to reconnect and grant it if they want it. |
| 404 | Unknown run, pool or repository name. Check the name; a run ID is 32 hex characters. |
| 409 | A profile, connection or repository requirement is not met. Read `body.error`; it names the rule. |
| 429 with `retry_after_seconds` | The run queue is full. Wait that long, then launch once more with the **same** idempotency key. |
| 5xx / no answer to a launch | The launch may or may not have happened. **Never launch again blindly**: call `agent_runs()` and look for it first. Relaunch only if it is not there, with the same idempotency key. |
| Run `failure.stage = "bootstrap"` | The workspace could not start the run. Retry once; if it repeats, report it to the user. |
