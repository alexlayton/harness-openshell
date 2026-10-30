#!/bin/sh
# Runs INSIDE the sandbox. Writes a stub Harness auth.json for the Claude
# subscription from the provider placeholder, then runs Harness.
#
#   claude-entry.sh [harness args...]
#   claude-entry.sh prompt --provider anthropic-claude --no-session "Say OK"
#   claude-entry.sh --provider anthropic-claude          # interactive UI
#
# The access token here is only a placeholder. OpenShell's proxy swaps in the
# real token on requests to api.anthropic.com. The far-future expiry stops
# Harness from trying to refresh it; the gateway does the refreshing.
set -eu

: "${HARNESS_CLAUDE_ACCESS_TOKEN:?provider harness-claude is not attached}"
: "${HARNESS_CLAUDE_ACCOUNT_ID:?pass --env HARNESS_CLAUDE_ACCOUNT_ID=<uuid>}"

HARNESS_CONFIG_DIR="${HARNESS_CONFIG_DIR:-/tmp/harness/config}"
HARNESS_STATE_DIR="${HARNESS_STATE_DIR:-/tmp/harness/state}"
export HARNESS_CONFIG_DIR HARNESS_STATE_DIR

umask 077
mkdir -p -m 700 "$HARNESS_CONFIG_DIR" "$HARNESS_STATE_DIR"
printf '{"anthropic-subscription":{"type":"oauth","access":"%s","refresh":"unused","expires":4102444800000,"accountId":"%s"}}\n' \
    "$HARNESS_CLAUDE_ACCESS_TOKEN" "$HARNESS_CLAUDE_ACCOUNT_ID" \
    > "$HARNESS_CONFIG_DIR/auth.json"

exec harness "$@"
