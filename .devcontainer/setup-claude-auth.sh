#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
  echo "Codespaces secret ANTHROPIC_AUTH_TOKEN is not set; Claude Code will not be authenticated." >&2
  exit 0
fi

claude_dir="${HOME}/.claude"
key_file="${claude_dir}/anthropic-api-key"
settings_file="${claude_dir}/settings.json"

mkdir -p "${claude_dir}"
umask 077
printf '%s' "${ANTHROPIC_AUTH_TOKEN}" > "${key_file}"

# Claude Code sends ANTHROPIC_AUTH_TOKEN as a Bearer token and prefers it over
# apiKeyHelper, but a Claude Console key must be sent as X-Api-Key. Blanking the
# variable in Claude Code's env makes it fall back to apiKeyHelper, which reads
# the key from a file because its subprocess inherits the blanked variable.
SETTINGS_FILE="${settings_file}" KEY_FILE="${key_file}" node <<'EOF'
const fs = require("fs");
const { SETTINGS_FILE, KEY_FILE } = process.env;
const settings = fs.existsSync(SETTINGS_FILE)
  ? JSON.parse(fs.readFileSync(SETTINGS_FILE, "utf8"))
  : {};
settings.apiKeyHelper = `cat "${KEY_FILE}"`;
settings.env = { ...settings.env, ANTHROPIC_AUTH_TOKEN: "" };
fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2) + "\n");
EOF

echo "Claude Code is configured to use the ANTHROPIC_AUTH_TOKEN Codespaces secret as its API key."
