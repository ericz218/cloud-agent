#!/usr/bin/env bash
# Boots the agent workspace. Idempotent: runs on every deploy/restart and
# rebuilds all generated config from env vars + this repo, so a fresh instance
# with the same disk (or an empty disk) converges to the same environment.
set -euo pipefail

DATA="${DATA_DIR:-/data}"
if ! mountpoint -q "$DATA"; then
  echo "[boot] WARNING: $DATA is not a mounted persistent disk; workspace will be lost on restart" >&2
fi

export HOME="$DATA/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache" XDG_STATE_HOME="$HOME/.local/state"
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="/opt/cloud-agent/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
export WORKSPACE="$DATA/workspace"
mkdir -p "$HOME" "$XDG_CONFIG_HOME/opencode" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" \
         "$XDG_STATE_HOME" "$NPM_CONFIG_PREFIX" "$WORKSPACE"

if [ -z "${OPENCODE_SERVER_PASSWORD:-}" ]; then
  echo "[boot] refusing to start: OPENCODE_SERVER_PASSWORD is not set (the UI would be public)" >&2
  exit 1
fi

# Login shells opened by the agent or the Render shell get the same environment.
cat > "$HOME/.cloud-agent-env" <<ENV
export HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_DATA_HOME="$XDG_DATA_HOME"
export XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_STATE_HOME="$XDG_STATE_HOME"
export NPM_CONFIG_PREFIX="$NPM_CONFIG_PREFIX" WORKSPACE="$WORKSPACE"
export PATH="$PATH"
ENV
grep -q cloud-agent-env "$HOME/.bashrc" 2>/dev/null || echo '. "$HOME/.cloud-agent-env"' >> "$HOME/.bashrc"
cp -n /opt/cloud-agent/agent/bashrc.example "$HOME/.bashrc.local" 2>/dev/null || true

# OpenCode: BYOK provider config (no secrets in the file) + global agent rules.
/opt/cloud-agent/scripts/gen-opencode-config.sh "$XDG_CONFIG_HOME/opencode/opencode.json"
cp /opt/cloud-agent/agent/AGENTS.md "$XDG_CONFIG_HOME/opencode/AGENTS.md"
echo "[boot] BYOK provider=${BYOK_PROVIDER:-openai-compatible} model=${BYOK_MODEL}"

# Git + GitHub: the credential helper reads GH_TOKEN from the environment at
# use time, so no token is written to disk.
git config --global init.defaultBranch main
git config --global push.autoSetupRemote true
git config --global pull.rebase false
git config --global credential.https://github.com.helper ''
git config --global --add credential.https://github.com.helper '!gh auth git-credential'
if [ -n "${GH_TOKEN:-}" ]; then
  if gh_user="$(gh api user --jq '.login + " " + (.id|tostring)' 2>/dev/null)"; then
    login="${gh_user% *}"; uid="${gh_user#* }"
    git config --global user.name "${GIT_USER_NAME:-$login}"
    git config --global user.email "${GIT_USER_EMAIL:-$uid+$login@users.noreply.github.com}"
    echo "[boot] GitHub authenticated as $login"
  else
    echo "[boot] WARNING: GH_TOKEN is set but GitHub rejected it" >&2
  fi
else
  echo "[boot] WARNING: GH_TOKEN not set; GitHub access disabled" >&2
fi
[ -n "${RENDER_API_KEY:-}" ] || echo "[boot] WARNING: RENDER_API_KEY not set; Render access disabled" >&2

cd "$WORKSPACE"
exec opencode serve --hostname "${LISTEN_HOST:-0.0.0.0}" --port "${PORT:-10000}"
