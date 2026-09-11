#!/usr/bin/env bash
set -euo pipefail

GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-GeorgesTech/promocode-test-technique-dev}"
LITELLM_DURATION="${LITELLM_DURATION:-2h}"
LITELLM_MODELS="${LITELLM_MODELS:-claude-opus-5-5}"
LITELLM_MAX_BUDGET="${LITELLM_MAX_BUDGET:-10}"
# LITELLM_RPM_LIMIT="${LITELLM_RPM_LIMIT:-60}"
# LITELLM_TPM_LIMIT="${LITELLM_TPM_LIMIT:-100000}"
LITELLM_KEY_ALIAS="${LITELLM_KEY_ALIAS:-test-indy-$(date +%Y%m%d-%H%M%S)}"
WORKSHOP_ACCESS_STATE_FILE="${WORKSHOP_ACCESS_STATE_FILE:-.devcontainer/workshop-access.local.json}"

required_commands=(curl gh jq)
for command_name in "${required_commands[@]}"; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
done

required_env=(LITELLM_BASE_URL LITELLM_ADMIN_KEY)
for env_name in "${required_env[@]}"; do
  if [[ -z "${!env_name:-}" ]]; then
    echo "Missing required environment variable: ${env_name}" >&2
    exit 1
  fi
done

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

if ! viewer_permission="$(gh repo view "${GITHUB_REPOSITORY}" --json viewerPermission --jq '.viewerPermission' 2>/dev/null)"; then
  echo "Cannot access GitHub repository: ${GITHUB_REPOSITORY}" >&2
  echo "Check that the repository exists and that your current 'gh' account has access." >&2
  echo "If the repo owner/name is different, run:" >&2
  echo "  export GITHUB_REPOSITORY=\"owner/repo\"" >&2
  exit 1
fi
echo "GitHub repository access OK: ${GITHUB_REPOSITORY} (${viewer_permission})"

if [[ "${viewer_permission}" != "ADMIN" ]]; then
  echo "Cannot manage repository Codespaces secrets without ADMIN permission." >&2
  echo "Current permission on ${GITHUB_REPOSITORY}: ${viewer_permission}" >&2
  echo "Ask a repository admin to run this script, or grant admin access to your GitHub account." >&2
  exit 1
fi

if ! gh api "repos/${GITHUB_REPOSITORY}/codespaces/secrets/public-key" >/dev/null 2>&1; then
  echo "Cannot write Codespaces secrets for: ${GITHUB_REPOSITORY}" >&2
  echo "You do not need to create the secrets manually, but GitHub must allow this account to manage them." >&2
  echo "Check that Codespaces is enabled for the repository and that your 'gh' account has admin access." >&2
  echo "You may also need to refresh GitHub CLI scopes:" >&2
  echo "  gh auth refresh -h github.com -s repo -s codespace" >&2
  exit 1
fi
echo "GitHub Codespaces secrets access OK: ${GITHUB_REPOSITORY}"

tmp_response="$(mktemp)"
trap 'rm -f "${tmp_response}"' EXIT

models_json="$(
  printf '%s' "${LITELLM_MODELS}" |
    jq -Rc 'split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))'
)"

if [[ "$(jq 'length' <<<"${models_json}")" -eq 0 ]]; then
  echo "LITELLM_MODELS must contain at least one model alias." >&2
  exit 1
fi

payload="$(
  jq -n \
    --arg key_alias "${LITELLM_KEY_ALIAS}" \
    --arg duration "${LITELLM_DURATION}" \
    --argjson models "${models_json}" \
    --argjson max_budget "${LITELLM_MAX_BUDGET}" \
    '{
      key_alias: $key_alias,
      duration: $duration,
      models: $models,
      max_budget: $max_budget,
      metadata: {
        purpose: "promocode-codespaces-workshop"
      }
    }'
)"

base_url="${LITELLM_BASE_URL%/}"
# Claude Code appends /v1/messages, so the Codespaces URL is the LiteLLM root.
anthropic_base_url="${LITELLM_ANTHROPIC_BASE_URL:-${base_url}}"
anthropic_base_url="${anthropic_base_url%/}"

echo "Creating a ${LITELLM_DURATION} LiteLLM virtual key for ${GITHUB_REPOSITORY}..."
curl -fsS "${base_url}/key/generate" \
  -H "Authorization: Bearer ${LITELLM_ADMIN_KEY}" \
  -H "Content-Type: application/json" \
  --data "${payload}" \
  --output "${tmp_response}"

virtual_key="$(jq -r '.key // .token // .api_key // empty' "${tmp_response}")"
if [[ -z "${virtual_key}" ]]; then
  echo "LiteLLM response did not include a generated key." >&2
  exit 1
fi

created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
umask 077
jq -n \
  --arg github_repository "${GITHUB_REPOSITORY}" \
  --arg litellm_base_url "${base_url}" \
  --arg litellm_key_alias "${LITELLM_KEY_ALIAS}" \
  --arg litellm_duration "${LITELLM_DURATION}" \
  --arg litellm_virtual_key "${virtual_key}" \
  --arg anthropic_base_url "${anthropic_base_url}" \
  --arg created_at "${created_at}" \
  '{
    github_repository: $github_repository,
    litellm_base_url: $litellm_base_url,
    litellm_key_alias: $litellm_key_alias,
    litellm_duration: $litellm_duration,
    litellm_virtual_key: $litellm_virtual_key,
    anthropic_base_url: $anthropic_base_url,
    created_at: $created_at
  }' > "${WORKSHOP_ACCESS_STATE_FILE}"
chmod 600 "${WORKSHOP_ACCESS_STATE_FILE}"
echo "Local cleanup state written to ${WORKSHOP_ACCESS_STATE_FILE}"

# Without --body, gh falls back to an interactive prompt (or stdin) and an
# accidental Enter stores an empty secret, so never let it prompt.
set_codespace_secret() {
  local secret_name="$1"
  local secret_value="$2"
  if [[ -z "${secret_value}" ]]; then
    echo "Refusing to set empty Codespaces secret: ${secret_name}" >&2
    exit 1
  fi
  GH_PROMPT_DISABLED=1 gh secret set "${secret_name}" \
    --repo "${GITHUB_REPOSITORY}" \
    --app codespaces \
    --body "${secret_value}" </dev/null
}

echo "Writing Codespaces secrets for ${GITHUB_REPOSITORY}..."
set_codespace_secret ANTHROPIC_BASE_URL "${anthropic_base_url}"
set_codespace_secret ANTHROPIC_API_KEY "${virtual_key}"
# Claude Code uses this bearer token when ANTHROPIC_BASE_URL points at a gateway.
set_codespace_secret ANTHROPIC_AUTH_TOKEN "${virtual_key}"

echo "Workshop access is ready. The LiteLLM key expires after ${LITELLM_DURATION}."
echo "Codespaces will expose ANTHROPIC_API_KEY and ANTHROPIC_BASE_URL for Claude."
echo "Already running Codespaces must be stopped and restarted to pick up new secret values."
echo
echo "Post-session cleanup commands:"
echo "  gh secret delete ANTHROPIC_BASE_URL --repo ${GITHUB_REPOSITORY} --app codespaces"
echo "  gh secret delete ANTHROPIC_API_KEY --repo ${GITHUB_REPOSITORY} --app codespaces"
echo "  gh secret delete ANTHROPIC_AUTH_TOKEN --repo ${GITHUB_REPOSITORY} --app codespaces"
echo
echo "Or run:"
echo "  ./.devcontainer/scripts/cleanup-workshop-access.sh"