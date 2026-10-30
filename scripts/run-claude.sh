#!/bin/sh
# Start a Harness (Claude subscription) sandbox, upload a project, run Harness.
#
#   scripts/run-claude.sh [-p PROJECT_DIR] [-n NAME] [-m MODEL] [PROMPT]
#
# Without PROMPT it opens the interactive UI. The sandbox is kept so you can
# download results; delete it with: openshell sandbox delete NAME
# Needs: CLAUDE_ACCOUNT_ID (printed by scripts/claude-provider.sh).
set -eu

image="${HARNESS_IMAGE:-ghcr.io/alexlayton/harness-openshell:latest}"
name="harness-claude"
model="claude-sonnet-4-6"
project=""
while getopts "p:n:m:" opt; do
    case "$opt" in
        p) project=$OPTARG ;;
        n) name=$OPTARG ;;
        m) model=$OPTARG ;;
        *) echo "usage: $0 [-p PROJECT_DIR] [-n NAME] [-m MODEL] [PROMPT]" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
: "${CLAUDE_ACCOUNT_ID:?export CLAUDE_ACCOUNT_ID first (see scripts/claude-provider.sh)}"

here=$(cd "$(dirname "$0")" && pwd)

openshell sandbox create --name "$name" --detach --from "$image" \
    --provider harness-claude \
    --env "HARNESS_CLAUDE_ACCOUNT_ID=$CLAUDE_ACCOUNT_ID" \
    -- sleep infinity

openshell sandbox upload "$name" "$here/claude-entry.sh" /sandbox/bin/
# A directory upload lands at <dest>/<directory name>, so upload into /sandbox
# and start in /sandbox/<directory name>. This honors .gitignore and omits
# .git (the sandbox copy has no history).
workdir=/sandbox
if [ -n "$project" ]; then
    project=${project%/}
    openshell sandbox upload "$name" "$project" /sandbox
    workdir="/sandbox/$(basename "$project")"
fi

if [ "$#" -gt 0 ]; then
    openshell sandbox exec "$name" --workdir "$workdir" -- \
        /sandbox/bin/claude-entry.sh prompt --provider anthropic-claude \
        --model "$model" --no-session "$*"
else
    openshell sandbox exec "$name" --workdir "$workdir" --tty -- \
        /sandbox/bin/claude-entry.sh --provider anthropic-claude --model "$model"
fi
