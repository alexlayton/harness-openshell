#!/bin/sh
# Create the "harness-claude" OpenShell provider from a DEDICATED Claude login.
#
# Why a new login: Claude refresh tokens are single-use. If the gateway reused
# the login in ~/.config/harness, whichever side refreshed first would log the
# other out. A new login has its own token chain, so your host login is safe.
#
# Secrets only live in this script's environment and a temp dir that is removed
# on exit. They are never printed.
set -eu

command -v harness >/dev/null 2>&1 || { echo "harness not found on PATH" >&2; exit 1; }
command -v openshell >/dev/null 2>&1 || { echo "openshell not found on PATH" >&2; exit 1; }

here=$(cd "$(dirname "$0")" && pwd)
profile="$here/../providers/subscriptions/harness-claude.yaml"
# Public OAuth client ID that Harness uses for Claude (crates/auth).
client_id="9d1c250a-e61b-44d9-88ed-5944d1962f5e"

if ! openshell profile list 2>/dev/null | grep -q '^harness-claude '; then
    openshell profile import -f "$profile"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

echo "Log in with the Claude account to use in sandboxes (this is a new session)."
HARNESS_CONFIG_DIR="$tmp" harness login anthropic-claude

vals=$(python3 - "$tmp/auth.json" <<'PY'
import json, shlex, sys
c = json.load(open(sys.argv[1]))["anthropic-subscription"]
for key, value in (
    ("HARNESS_CLAUDE_ACCESS_TOKEN", c["access"]),
    ("CLAUDE_REFRESH_TOKEN", c["refresh"]),
    ("CLAUDE_EXPIRES_MS", c["expires"]),
    ("CLAUDE_ACCOUNT_ID", c["accountId"]),
):
    print(f"{key}={shlex.quote(str(value))}")
PY
)
eval "$vals"
export HARNESS_CLAUDE_ACCESS_TOKEN CLAUDE_REFRESH_TOKEN

openshell provider create --name harness-claude --type harness-claude \
    --credential HARNESS_CLAUDE_ACCESS_TOKEN

openshell provider refresh configure harness-claude \
    --credential-key HARNESS_CLAUDE_ACCESS_TOKEN \
    --strategy oauth2-refresh-token \
    --material "client_id=$client_id" \
    --secret-material-env refresh_token=CLAUDE_REFRESH_TOKEN \
    --credential-expires-at "$CLAUDE_EXPIRES_MS"

openshell provider refresh status harness-claude || true

echo
echo "Done. Account id (not a secret), used by the sandbox command:"
echo "  export CLAUDE_ACCOUNT_ID=$CLAUDE_ACCOUNT_ID"
