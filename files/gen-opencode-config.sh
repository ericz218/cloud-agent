#!/usr/bin/env bash
# Writes the OpenCode config from BYOK_* env vars. The API key itself never lands
# on disk: the config references it as {env:BYOK_API_KEY}.
#
#   BYOK_PROVIDER   anthropic | openai | openrouter | openai-compatible (default)
#   BYOK_BASE_URL   API base URL (optional for anthropic/openai/openrouter)
#   BYOK_API_KEY    API key (secret, read at request time)
#   BYOK_MODEL      model ID sent to the API, e.g. claude-sonnet-4-5, gpt-5, deepseek/deepseek-chat
#   BYOK_SMALL_MODEL   optional cheaper model for titles/summaries (defaults to BYOK_MODEL)
#   BYOK_EXTRA_MODELS  optional comma-separated extra model IDs selectable in the UI
set -euo pipefail

out="${1:?usage: gen-opencode-config.sh <output.json>}"
provider="${BYOK_PROVIDER:-openai-compatible}"
model="${BYOK_MODEL:?BYOK_MODEL is required}"
small="${BYOK_SMALL_MODEL:-$model}"

case "$provider" in
  anthropic)  npm="@ai-sdk/anthropic";           default_url="https://api.anthropic.com/v1" ;;
  openai)     npm="@ai-sdk/openai";              default_url="https://api.openai.com/v1" ;;
  openrouter) npm="@openrouter/ai-sdk-provider"; default_url="https://openrouter.ai/api/v1" ;;
  openai-compatible|compatible|custom)
              npm="@ai-sdk/openai-compatible";   default_url="" ;;
  *) echo "gen-opencode-config: unknown BYOK_PROVIDER '$provider'" >&2; exit 1 ;;
esac
base_url="${BYOK_BASE_URL:-$default_url}"
[ -n "$base_url" ] || { echo "gen-opencode-config: BYOK_BASE_URL is required for $provider" >&2; exit 1; }

models_csv="$model,$small${BYOK_EXTRA_MODELS:+,$BYOK_EXTRA_MODELS}"

render_mcp_enabled=false
[ -n "${RENDER_API_KEY:-}" ] && render_mcp_enabled=true

mkdir -p "$(dirname "$out")"
jq -n \
  --arg npm "$npm" --arg kind "$provider" --arg url "$base_url" \
  --arg model "$model" --arg small "$small" --arg models "$models_csv" \
  --argjson render "$render_mcp_enabled" \
  '{
    "$schema": "https://opencode.ai/config.json",
    autoupdate: false,
    share: "disabled",
    enabled_providers: ["byok"],
    model: ("byok/" + $model),
    small_model: ("byok/" + $small),
    provider: {
      byok: {
        npm: $npm,
        name: ("BYOK (" + $kind + ")"),
        options: { baseURL: $url, apiKey: "{env:BYOK_API_KEY}" },
        models: ($models | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))
                 | unique | map({key: ., value: {name: .}}) | from_entries)
      }
    },
    permission: {
      edit: "allow",
      webfetch: "allow",
      bash: { "*": "allow", "git push --force*": "deny", "git push -f*": "deny", "git push * --force*": "deny", "rm -rf /*": "deny" }
    },
    mcp: {
      render: {
        type: "remote",
        url: "https://mcp.render.com/mcp",
        headers: { Authorization: "Bearer {env:RENDER_API_KEY}" },
        enabled: $render
      }
    }
  }' > "$out"
