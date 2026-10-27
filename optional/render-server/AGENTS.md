# Cloud agent workspace rules

You run on an always-on Linux server (Render). The user drives you from a phone
and usually cannot see a terminal, so do the work end to end and report results.

## Environment
- Persistent disk: `/data`. Repos live in `$WORKSPACE` (`/data/workspace/<repo>`). `$HOME` is `/data/home`.
  Anything outside `/data` is wiped on every restart/deploy.
- Tools: git, gh, node/npm (+ pnpm/yarn via corepack), python3/pip/venv, uv, curl, jq, rg, fd,
  build-essential, render (Render CLI), `render-deploy-check` (see below). Docker is NOT available.
- Credentials are in environment variables: `GH_TOKEN` (GitHub), `RENDER_API_KEY` (Render),
  `BYOK_API_KEY` (LLM). git over https uses GH_TOKEN automatically through gh.
- **Never print, echo, log, write to a file, or commit any secret or env var value.** Don't run
  `env`, `printenv`, `set` or `cat` on files that may hold secrets. If a project needs secrets,
  reference the env var name or set it in Render's dashboard/API, never in the repo.

## "Open project X"
1. Resolve the repo: `gh repo list --limit 200` / `gh search repos` if only a partial name is given.
2. If `$WORKSPACE/<name>` exists: `git fetch --all --prune`, show status. Otherwise `gh repo clone owner/name "$WORKSPACE/<name>"`.
3. Report: current branch, uncommitted changes, ahead/behind, last 5 commits, open PRs (`gh pr list`),
   latest CI runs (`gh run list -L 5`), and Render status (`render-deploy-check` inside the repo).

## Development loop
- GitHub is the source of truth. Never leave meaningful work only on this disk: commit and push before
  you finish a task or stop for input. Use a feature branch unless the user said to work on main
  (or the repo is clearly a single-branch project where they deploy from main).
- Install deps with the project's own tooling (lockfile-respecting: `npm ci`, `pnpm i --frozen-lockfile`, `uv sync`, ...).
- Run the project's build/tests/lint before committing. Fix failures you caused.
- Small, descriptive commits. Show `git diff --stat` in your report.
- No force-push to main/master, no deleting branches/repos/services, no history rewrites on shared
  branches unless the user explicitly asks.

## CI (GitHub Actions)
- After pushing: `gh run list --branch <b> -L 5`, then `gh run watch <id> --exit-status`.
- On failure: `gh run view <id> --log-failed`, fix, push, watch again.

## Render deployments
- `render-deploy-check --wait` (run inside the repo) finds services built from this repo+branch, waits for
  the deploy of HEAD, prints status, the live commit SHA and failure logs. Exit 0 = HEAD is live.
- Services with auto-deploy deploy on push. If auto-deploy is off, trigger one:
  `curl -fsS -X POST -H "Authorization: Bearer $RENDER_API_KEY" https://api.render.com/v1/services/<id>/deploys`.
- The `render` MCP tools (list services, deploys, logs, metrics, env vars) and the `render` CLI
  (`render services -o json`, `render logs -r <id> -o text`) are available too.
- Always verify the deployed commit equals the SHA you pushed, then check recent app logs for errors and
  hit the service URL (e.g. its health endpoint) with curl.
- On deploy failure: read build/app logs, fix the code or config, push, verify again.

## Final report (keep it short, phone-readable)
What changed · branch + commit SHA · tests · CI result · Render deploy status + live SHA + URL · anything
the user must do.
