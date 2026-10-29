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

`.github/workflows/image.yml` builds `linux/amd64` and `linux/arm64` natively,
compiles Harness from source, and pushes a multi-arch image to GHCR:

```sh
gh workflow run image.yml -f harness_ref=v0.8.0
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
# linux/amd64 gateway host: published release binary
docker build -f image/Dockerfile -t harness-openshell:local image/

# linux/arm64 (VM driver on Apple Silicon): no arm64 Linux release exists,
# so compile from source. This is heavy; do it on a bigger machine or in CI.
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

## Notes

- State goes to `/tmp/harness`. It is lost when the sandbox is deleted.
- The profile `binaries` path must match the path in the image.
- Git pushes, package installs, and other network calls are denied until
  policy allows them. Add a provider (for example `github`) or a `--policy`.
- `harness prompt` does not need the update check; the interactive TUI may
  log a failed release check. This is harmless.
