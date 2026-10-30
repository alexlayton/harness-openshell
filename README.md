# Harness in OpenShell

Run the [Harness](../harness) coding agent inside an OpenShell sandbox.
This follows the OpenCode example in the OpenShell "Run Your First Agent" guide.

| Piece | File | Purpose |
|---|---|---|
| Provider profile | `providers/harness-openrouter.yaml` | Stores `OPENROUTER_API_KEY`. Only `/usr/local/bin/harness` may use it, only toward `openrouter.ai`. |
| Provider profile | `providers/harness-opencode-go.yaml` | Same for OpenCode Go (`opencode.ai`). |
| Sandbox image | `image/Dockerfile` | Ubuntu 24.04 with `harness` at `/usr/local/bin/harness`, `git`, and `curl`. |

Harness never sees the real key. The sandbox env holds a placeholder
(`openshell:resolve:env:...`) and the supervisor swaps in the real key for
requests to the profile endpoint.

Only API-key providers fit this model. `copilot`, `codex`, and `claude` use
OAuth tokens in `auth.json`, and a sandbox would hold the real tokens.

## 1. Import profiles and create a provider

```sh
openshell profile import -f providers/harness-openrouter.yaml
OPENROUTER_API_KEY=sk-or-... \
  openshell provider create --name harness-openrouter \
    --type harness-openrouter --from-existing
```

## 2. Get the image

### Option A: build on GitHub (no local engine needed)

`.github/workflows/image.yml` builds `linux/amd64` and `linux/arm64` natively
on their own runners, installs the published Harness release for each, and
pushes a multi-arch image to GHCR:

```sh
gh workflow run image.yml -f harness_ref=v0.9.0
gh run watch
```

The image is `ghcr.io/alexlayton/harness-openshell:latest` (also tagged with the
Harness ref). A new GHCR package is private. Make it public in the package
settings so the gateway can pull it, or give the gateway registry credentials.
Then use `--from ghcr.io/alexlayton/harness-openshell:latest` below.

### Option B: build locally

`openshell` needs an image the gateway can reach. The VM driver checks local
Docker/Podman first, then a registry. A rootfs `.tar` also works.

```sh
# Installs the published release for the build host's architecture
docker build -f image/Dockerfile -t harness-openshell:local image/

# Unreleased commit only: compile from source (slow, memory-hungry)
docker build -f image/Dockerfile --build-arg HARNESS_SOURCE=build \
  -t harness-openshell:local ../harness
```

For a remote gateway, push the image to a registry the gateway can pull from.

## 3. Run

```sh
# interactive TUI
openshell sandbox create --name harness --from harness-openshell:local \
  --provider harness-openrouter -- harness --provider openrouter

# one headless prompt
openshell sandbox create --name harness-job --no-keep --from harness-openshell:local \
  --provider harness-openrouter -- \
  harness prompt --provider openrouter --no-session "Say OK"

# work on a local project
openshell sandbox create --name harness-proj --from harness-openshell:local \
  --provider harness-openrouter --upload .:/sandbox
# then run `harness --provider openrouter` in the shell that opens
```

Check access: `openshell logs <name> --tail`. If a request is denied, see
`openshell rule get <name> --status pending` and approve it if you want it.

## Claude / Codex subscriptions (experimental)

Harness keeps these logins in `~/.config/harness/auth.json` and refreshes them
with single-use refresh tokens. **Do not copy that file into a sandbox:** the
first side to refresh logs the other out, and the sandbox would hold real
tokens. Instead, the gateway holds a separate login and the sandbox only sees
a placeholder.

```sh
# Once: new Claude login (browser) -> gateway provider with token refresh
scripts/claude-provider.sh
export CLAUDE_ACCOUNT_ID=...   # printed at the end; not a secret

# Run (creates the sandbox, uploads the script and project, starts Harness)
scripts/run-claude.sh -p ~/Code/some-project "Summarize this project"
scripts/run-claude.sh -p ~/Code/some-project            # interactive UI
```

`scripts/claude-entry.sh` runs inside the sandbox. It writes a stub
`auth.json` from the placeholder, with a far-future expiry so Harness never
tries to refresh it, then runs `harness`. The sandbox is kept after the run;
remove it with `openshell sandbox delete harness-claude`. The Claude route is an unofficial subscription protocol and can
violate provider terms. Codex follows the same pattern with
`providers/subscriptions/harness-codex.yaml`; it is not scripted yet.

## GitHub Copilot subscription (experimental)

Different from Claude: the long-lived GitHub token is stored as a plain
provider credential (no gateway refresh). Inside the sandbox, Harness trades
the placeholder for a short-lived Copilot token itself; OpenShell swaps in the
real GitHub token only on that one call (`api.github.com/copilot_internal/**`).
The profile is for individual plans; edit the Copilot host for business plans.

```sh
scripts/copilot-provider.sh                      # new GitHub device login
scripts/run-copilot.sh -p ~/Code/some-project "Say OK"
scripts/run-copilot.sh -m gpt-4o "Say OK"        # pick a model
```

`scripts/copilot-entry.sh` runs inside the sandbox and writes the stub
`auth.json` (already-expired access token, placeholder as `refresh`).

## Getting files in and out

`create --upload` cannot be combined with a command. Create the sandbox
first, upload, then run the work with `exec`:

```sh
openshell sandbox create --name work --detach --from IMAGE --provider P -- sleep infinity
openshell sandbox upload work ./my-project /sandbox            # lands at /sandbox/my-project
openshell sandbox upload work ./script.sh /sandbox/bin/       # exec bit is kept
openshell sandbox exec work --workdir /sandbox/my-project -- harness prompt ...
openshell sandbox download work /sandbox/my-project ./results    # copy changes back
```

Uploads are copies. Edits made by the agent stay in the sandbox until you
download them. Only `/sandbox` (the working directory) and `/tmp` are writable.
Bind mounts of host folders exist for the VM driver but need extra gateway
opt-in and expose host files; avoid them for untrusted work.

## Notes

- State goes to `/tmp/harness`. It is lost when the sandbox is deleted.
- The profile `binaries` path must match the path in the image.
- Git pushes, package installs, and other network calls are denied until
  policy allows them. Add a provider (for example `github`) or a `--policy`.
- `harness prompt` does not need the update check; the interactive TUI may
  log a failed release check. This is harmless.
