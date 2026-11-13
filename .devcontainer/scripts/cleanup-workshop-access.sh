#!/usr/bin/env bash
set -euo pipefail

WORKSHOP_ACCESS_STATE_FILE="${WORKSHOP_ACCESS_STATE_FILE:-.devcontainer/workshop-access.local.json}"
CODESPACE_NAME="${CODESPACE_NAME:-}"

usage() {
  cat <<'USAGE'
Usage:
  ./.devcontainer/scripts/cleanup-workshop-access.sh [--codespace CODESPACE_NAME]

Environment:
  WORKSHOP_ACCESS_STATE_FILE  Path to the local cleanup state file.
  LITELLM_ADMIN_KEY           LiteLLM master/admin key, required to revoke the virtual key.
  CODESPACE_NAME              Optional Codespace name to delete.

This deletes GitHub Codespaces secrets, revokes the LiteLLM virtual key saved
by provision-workshop-access.sh, and optionally deletes one Codespace owned by
the current GitHub account.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --codespace)
      if [[ -z "${2:-}" ]]; then
        echo "Missing value for --codespace" >&2
        exit 1
      fi
      CODESPACE_NAME="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

required_commands=(curl gh jq)
for command_name in "${required_commands[@]}"; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
done

if [[ ! -f "${WORKSHOP_ACCESS_STATE_FILE}" ]]; then
  echo "Cleanup state file not found: ${WORKSHOP_ACCESS_STATE_FILE}" >&2
  echo "Run provision-workshop-access.sh first, or set WORKSHOP_ACCESS_STATE_FILE." >&2
  exit 1
fi

github_repository="$(jq -r '.github_repository // empty' "${WORKSHOP_ACCESS_STATE_FILE}")"
litellm_base_url="$(jq -r '.litellm_base_url // empty' "${WORKSHOP_ACCESS_STATE_FILE}")"
litellm_virtual_key="$(jq -r '.litellm_virtual_key // empty' "${WORKSHOP_ACCESS_STATE_FILE}")"

if [[ -z "${github_repository}" || -z "${litellm_base_url}" || -z "${litellm_virtual_key}" ]]; then
  echo "Cleanup state file is missing required fields." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

cleanup_failed=0
secret_names=(
  ANTHROPIC_BASE_URL
  ANTHROPIC_API_KEY
  ANTHROPIC_AUTH_TOKEN
)

echo "Deleting Codespaces secrets for ${github_repository}..."
for secret_name in "${secret_names[@]}"; do
  if gh secret delete "${secret_name}" \
    --repo "${github_repository}" \
    --app codespaces >/dev/null 2>&1; then
    echo "Deleted Codespaces secret: ${secret_name}"
  else
    echo "Warning: could not delete Codespaces secret: ${secret_name}" >&2
    cleanup_failed=1
  fi
done

if [[ -z "${LITELLM_ADMIN_KEY:-}" ]]; then
  echo "Missing LITELLM_ADMIN_KEY; cannot revoke the LiteLLM virtual key." >&2
  cleanup_failed=1
else
  delete_payload="$(jq -n --arg key "${litellm_virtual_key}" '{ keys: [$key] }')"
  if curl -fsS "${litellm_base_url%/}/key/delete" \
    -H "Authorization: Bearer ${LITELLM_ADMIN_KEY}" \
    -H "Content-Type: application/json" \
    --data "${delete_payload}" \
    --output /dev/null; then
    echo "Revoked LiteLLM virtual key."
  else
    echo "Warning: could not revoke LiteLLM virtual key." >&2
    cleanup_failed=1
  fi
fi

if [[ -n "${CODESPACE_NAME}" ]]; then
  echo "Deleting Codespace: ${CODESPACE_NAME}"
  if gh codespace delete --codespace "${CODESPACE_NAME}" --force; then
    echo "Deleted Codespace: ${CODESPACE_NAME}"
  else
    echo "Warning: could not delete Codespace: ${CODESPACE_NAME}" >&2
    echo "The Codespace may belong to another GitHub account." >&2
    cleanup_failed=1
  fi
fi

if [[ "${cleanup_failed}" -eq 0 ]]; then
  rm -f "${WORKSHOP_ACCESS_STATE_FILE}"
  echo "Removed local cleanup state: ${WORKSHOP_ACCESS_STATE_FILE}"
  echo "Workshop cleanup complete."
else
  echo "Workshop cleanup finished with warnings. Keeping state file for retry: ${WORKSHOP_ACCESS_STATE_FILE}" >&2
  exit 1
fi
