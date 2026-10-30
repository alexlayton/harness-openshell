#!/bin/sh
# Start a Harness (GitHub Copilot) sandbox, upload a project, run Harness.
#
#   scripts/run-copilot.sh [-p PROJECT_DIR] [-n NAME] [-m MODEL] [PROMPT]
#
# Without PROMPT it opens the interactive UI. Without -m, Harness picks a model
# the account can use. The sandbox is kept; delete it with:
#   openshell sandbox delete NAME
set -eu

image="${HARNESS_IMAGE:-ghcr.io/alexlayton/harness-openshell:latest}"
name="harness-copilot"
model=""
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

here=$(cd "$(dirname "$0")" && pwd)

openshell sandbox create --name "$name" --detach --from "$image" \
    --provider harness-copilot -- sleep infinity

openshell sandbox upload "$name" "$here/copilot-entry.sh" /sandbox/bin/

# A directory upload lands at <dest>/<directory name>.
workdir=/sandbox
if [ -n "$project" ]; then
    project=${project%/}
    openshell sandbox upload "$name" "$project" /sandbox
    workdir="/sandbox/$(basename "$project")"
fi

model_args=""
[ -n "$model" ] && model_args="--model $model"

if [ "$#" -gt 0 ]; then
    # shellcheck disable=SC2086
    openshell sandbox exec "$name" --workdir "$workdir" -- \
        /sandbox/bin/copilot-entry.sh prompt --provider github-copilot \
        $model_args --no-session "$*"
else
    # shellcheck disable=SC2086
    openshell sandbox exec "$name" --workdir "$workdir" --tty -- \
        /sandbox/bin/copilot-entry.sh --provider github-copilot $model_args
fi
