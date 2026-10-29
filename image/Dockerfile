# Sandbox image for the Harness coding agent.
#
#   HARNESS_SOURCE=release  (default) install the published release with
#                           install.sh. Releases exist for linux x86-64 only.
#   HARNESS_SOURCE=build    compile from source. Use this for linux/arm64,
#                           for example the VM driver on Apple Silicon.
#
# Build context: the Harness repository root for HARNESS_SOURCE=build, e.g.
#   docker build -f ../openshell-experiments/image/Dockerfile \
#     --build-arg HARNESS_SOURCE=build -t harness-openshell:local ../harness
# For HARNESS_SOURCE=release any small context works (`image/`).
ARG HARNESS_SOURCE=release
ARG HARNESS_VERSION=v0.8.0

FROM ubuntu:24.04 AS harness-release
ARG HARNESS_VERSION
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://raw.githubusercontent.com/alexlayton/harness/main/install.sh \
    | bash -s -- --version "${HARNESS_VERSION}" --bin-dir /out

FROM rust:1-bookworm AS harness-build
WORKDIR /src
COPY . .
RUN CARGO_BUILD_JOBS=4 cargo build --profile fast-release --locked --bin harness \
    && install -D target/fast-release/harness /out/harness

FROM harness-${HARNESS_SOURCE} AS harness-bin

FROM ubuntu:24.04
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash ca-certificates curl git iproute2 less openssh-client \
    && rm -rf /var/lib/apt/lists/*

# The base image ships user "ubuntu" at UID 1000. OpenShell runs the workload
# as a non-root user, so give that UID the name "sandbox".
RUN (userdel -r ubuntu 2>/dev/null || true) \
    && useradd -M -u 1000 -s /bin/bash -d /sandbox sandbox \
    && mkdir -p /sandbox && chown sandbox:sandbox /sandbox

COPY --from=harness-bin /out/harness /usr/local/bin/harness

USER sandbox
WORKDIR /sandbox

# Keep Harness state in /tmp: it is one of the few writable places in a sandbox.
ENV HARNESS_CONFIG_DIR=/tmp/harness/config \
    HARNESS_STATE_DIR=/tmp/harness/state
