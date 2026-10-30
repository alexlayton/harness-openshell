#!/bin/sh
# Runs INSIDE the sandbox. Writes a stub Harness auth.json for GitHub Copilot,
# then runs Harness.
#
#   copilot-entry.sh [harness args...]
#   copilot-entry.sh prompt --provider copilot --no-session "Say OK"
#   copilot-entry.sh --provider copilot                  # interactive UI
#
# "refresh" holds the provider PLACEHOLDER for the GitHub token. The stub's
# access token is already expired (expires=1), so Harness exchanges the
# placeholder for a real, short-lived Copilot token on first use. OpenShell's
# proxy swaps in the real GitHub token on that exchange call.
set -eu

: "${HARNESS_COPILOT_GITHUB_TOKEN:?provider harness-copilot is not attached}"

HARNESS_CONFIG_DIR="${HARNESS_CONFIG_DIR:-/tmp/harness/config}"
HARNESS_STATE_DIR="${HARNESS_STATE_DIR:-/tmp/harness/state}"
export HARNESS_CONFIG_DIR HARNESS_STATE_DIR

umask 077
mkdir -p -m 700 "$HARNESS_CONFIG_DIR" "$HARNESS_STATE_DIR"
printf '{"github-copilot":{"type":"oauth","access":"expired","refresh":"%s","expires":1}}\n' \
    "$HARNESS_COPILOT_GITHUB_TOKEN" > "$HARNESS_CONFIG_DIR/auth.json"

exec harness "$@"
