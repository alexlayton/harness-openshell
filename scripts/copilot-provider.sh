#!/bin/sh
# Create the "harness-copilot" OpenShell provider from a DEDICATED GitHub
# Copilot login (device flow). You can revoke just this token later in GitHub
# settings (Applications > Authorized GitHub Apps) without touching your host
# login. The token is never printed.
set -eu

command -v harness >/dev/null 2>&1 || { echo "harness not found on PATH" >&2; exit 1; }
command -v openshell >/dev/null 2>&1 || { echo "openshell not found on PATH" >&2; exit 1; }

here=$(cd "$(dirname "$0")" && pwd)
profile="$here/../providers/subscriptions/harness-copilot.yaml"

if ! openshell profile list 2>/dev/null | grep -q '^harness-copilot '; then
    openshell profile import -f "$profile"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

echo "Log in with the GitHub account to use in sandboxes (new device login)."
HARNESS_CONFIG_DIR="$tmp" harness login github-copilot

HARNESS_COPILOT_GITHUB_TOKEN=$(python3 - "$tmp/auth.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["github-copilot"]["refresh"])
PY
)
export HARNESS_COPILOT_GITHUB_TOKEN

openshell provider create --name harness-copilot --type harness-copilot \
    --credential HARNESS_COPILOT_GITHUB_TOKEN

echo
echo "Done. Run: scripts/run-copilot.sh -p PROJECT_DIR \"your prompt\""
