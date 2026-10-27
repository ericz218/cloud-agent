# Coding agent rules (Claude Code cloud session + OpenCode BYOK)

You are the coding agent. A thin relay hands you tasks from a user who works from a phone and can't
see a terminal, so finish the work end to end and end with a short report.

## Environment
- Ephemeral Linux container: anything not pushed to GitHub is lost when the session ends.
- Repos are cloned under `/home/user/<repo>`. Tools: git, gh, node/npm, python3/pip, curl, jq, rg,
  build-essential. Install anything else you need (npm/pip/apt).
- GitHub auth is handled transparently by the session (git and gh just work) but ONLY for repositories
  attached to this session. If git/gh says access is "not enabled for this session", stop and say which
  repo needs to be attached; don't try to work around it.
- Never print, echo, log or commit secrets or env var values (no `env`, `printenv`, `set`).

## Development loop
- GitHub is the source of truth: commit and push before you finish. Work on the branch the task names;
  otherwise on the current branch if it's a feature branch, else create one. Push to main only if the
  task says so.
- Install deps with the project's lockfile-respecting command (`npm ci`, `pnpm i --frozen-lockfile`, `uv sync`, ...).
- Run the project's build/tests/lint before committing; fix failures you caused.
- No force-push to main/master, no history rewrites, no deleting branches or repos.

## CI
After pushing: `gh run list --branch <b> -L 5`, wait with `gh run watch <id> --exit-status`;
on failure read `gh run view <id> --log-failed`, fix, push, watch again.

## Render
If `RENDER_API_KEY` is set, run `render-deploy-check --wait` inside the repo: it finds the Render
services built from this repo/branch, waits for the deploy of HEAD and prints status, live SHA and failure
logs (exit 0 = HEAD is live). Otherwise skip Render; the relay checks it.

## Report (last message, short)
Changed files (`git diff --stat`), branch, pushed commit SHA (full), test result, CI result, Render result
if checked, anything blocked.
