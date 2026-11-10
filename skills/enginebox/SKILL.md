---
name: enginebox
description: Run coding agents on Engine Box through the hosted `enginebox` MCP server. Use when the user (or your own plan) needs code built, fixed, reviewed or investigated in a repository: launch a Codex, Claude or Cursor run on a branch of an approved repository, poll it to the end, hand the user its live branch preview URL, merge it when they say so, cancel it, or list and create hosted repositories. Also use on an Engine Box tool error (unauthorized, insufficient scope, queue full). Not for creating or deleting machines, templates or storage; that is owner administration and is not available here.
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
| Start work | `pool_agent_launch({pool, provider, prompt, repository, branch, idempotency_key, timeout_seconds?, model?, run_kind?})` |
| Follow a run (and its preview) | `pool_agent_run({pool, run_id})` until it ends; then its `preview` |
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
2. **Pick a branch** for the work, such as `grok/<task-slug>`. One task, one branch; follow-ups on
   the same task reuse it.
3. **Write a complete prompt.** The agent starts cold. Include: the goal in one sentence, the
   repository, what "done" means as checks it can run (tests, a build, a command), what not to
   touch, and this, with the names filled in:

   > Clone the repository, check out `<branch>` (create it from the default branch if it does not
   > exist) and push your work to `<branch>`. Never push to the default branch. Engine Box runs a
   > live preview of `<branch>` from `.enginebox/config.json`'s `dev` section and redeploys it on
   > every push. If the repository has a dev server and that section is missing, add it (see
   > "Preview config" below) in the same push. End with what changed, the commit, and the exact
   > checks you ran with their results.

4. **Launch** `pool_agent_launch` with `repository`, `branch` and an `idempotency_key` such as
   `<task-slug>:<attempt>`. Within one sign-in token (access tokens renew hourly) the same key
   returns the existing run instead of starting another.
5. **Poll** `pool_agent_run` while the run is `queued` or `running`. Back off: about every 30
   seconds at first, then every few minutes for long runs. Report progress only when something
   changes.
6. **Read the result**: `status`, output, `failure` (`{stage, reason}`).
7. **Read the preview.** Engine Box starts it by itself when a run with a branch succeeds; you never
   start one. Read `preview` on the run:

   | `preview.status` | Do |
   |---|---|
   | `ready` | Give the user `preview.url` with the summary. |
   | `queued`, `preparing`, `updating` | Poll `pool_agent_run` again every 30-60 s for a few minutes until `ready`. |
   | `not-configured` | The branch has no `dev` section. Launch one follow-up run on the **same branch** to add the preview config (below), then read the preview again. Ask nothing. |
   | an `error`, `unhealthy`, `update-failed` | Launch one follow-up run on the same branch with the error to fix the dev server or template; if it fails again, report the error. |
   | `preview` is null | Previews are off on this Engine Box; just report the branch. |

8. **Report**: what changed, the branch, the preview URL, the evidence.
9. **Merge only when the user says so** ("merge it", "ship it", "merge <branch>"). Then launch a short
   run on the same repository: "Merge `<branch>` into the default branch, run the tests and build,
   and push the default branch only if they pass; otherwise push nothing and report why." Report
   the merge commit. Deploying beyond that stays with the owner's process.

### Preview config

What the agent writes when the preview is `not-configured` (the same shape Engine Box's own config
generator writes). `.enginebox/config.json` gets a top-level `"dev": {"template": "./templates/dev.json"}`
(keep anything else in the file), and `.enginebox/templates/dev.json`:

```json
{"schema_version": 1, "kind": "dev", "id": "dev", "revision": 1,
 "image": "node@sha256:<digest>",
 "prepare": ["pnpm", "install", "--frozen-lockfile"],
 "command": ["pnpm", "dev", "--host", "0.0.0.0"],
 "installInputs": ["package.json", "pnpm-lock.yaml"],
 "ports": [{"name": "web", "protocol": "http", "port": 5173, "expose": true}],
 "health": {"port": "web", "path": "/"},
 "writableDirs": ["node_modules/.vite"], "memoryMiB": 2048}
```

Tell the agent: pin the image by digest (Docker Hub's `node:24-bookworm-slim` manifest
`docker-content-digest`); `installInputs` lists every `package.json` and the lockfile; the dev
command listens on `0.0.0.0` at the declared port; app data goes under `$ENGINEBOX_DATA_DIR`
(wrangler: `--local --persist-to /data/wrangler`); `writableDirs` names caches only, never all of
`node_modules`; keep the repository's package manager. If the dev server needs real secrets, leave
the preview out and say so.

## Acting without asking

Engine Box is built for an agent to drive. Do not ask the user before routine steps that stay
inside the granted pools: launching a run for work they asked for, a follow-up run that adds or
fixes the preview config, retrying a failed run once with a better prompt, splitting a task into
several runs, cancelling your own stuck run, or creating a repository in a project granted
`write`. Never merge into the default branch unless the user said to. Do ask before anything that spends beyond what was asked
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
