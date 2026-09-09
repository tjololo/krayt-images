# syntax=docker/dockerfile:1 # renovate: ignore
# krayt-dev — the dogfooding agent image: krayt's own dev toolchain layered on the published
# Claude Code agent image, so an agent running `krayt run --image krayt-dev --agent claude-code`
# against krayt's own repo can build, test, lint, and regenerate protocol code inside the sandbox
# before returning its patch (§6.14, §8.2).
#
# It inherits FROM krayt-agent-claude-code rather than re-deriving that image: the non-root `agent`
# user (uid 1000, §8.2 — Claude Code refuses uid 0), the version-pinned Claude Code CLI, the
# DISABLE_* egress env, and the ENTRYPOINT — including the §8.2 credential and KRAYT_CA_CERT
# contracts. Keeping a second near-identical copy of that logic here is what previously let the
# two drift until a shape-translated run exited 78 before Claude started.
#
# This image DOES add an entrypoint of its own (entrypoint.sh) — the one place it departs from
# being purely additive. It only wraps: it starts dockerd, then drops back to `agent` and execs
# krayt-agent-entrypoint with the arguments untouched, so every §8.2 contract still runs. See that
# file's header for why kind forces the issue, and the ENTRYPOINT block at the bottom.
#
# Nothing else needs a setup step. It ships `gh`, but gh authenticates itself: krayt.yaml injects
# GH_TOKEN at the host proxy (§6.6.1), which means the container is configured with a
# GH_TOKEN env var holding a placeholder — and reading GH_TOKEN from the environment is gh's own
# first-choice auth path. The proxy swaps the placeholder for the real token on the way out. No
# script has to move a credential anywhere.
#
# One FROM, and every block below it adds one tool on top of the base — which is the whole agent
# image — with the entrypoint above as the single exception to being purely additive.
#
# KEEP THIS DIGEST-PINNED. agent-images.yml re-points the `:<cli-version>` tag on every build off
# main, so the tag alone floats: this image would silently absorb base changes on any unrelated
# rebuild, and Renovate would never open the digest-bump PR that is how a base change is meant to
# arrive here (see dev-image.yml's `paths` comment). Renovate's dockerfile manager appends and
# maintains the digest (`pinDigests: true`, renovate.json) — the line is tag-only until its first
# PR lands, which is tracked in HUMAN_TODO.md.
FROM ghcr.io/418-cloud/krayt-agent-claude-code:2.1.226

# Tool versions, pinned so Renovate's custom regex manager (renovate.json) can bump them
# independently of the base image tag. `make proto` (Nix) stays the source of truth for the
# *committed* generated code; this toolchain is only for an agent regenerating it mid-run
# (see proto-direct.sh) when it edits internal/protocol/krayt.proto.
ARG GO_VERSION=1.26.3
ARG PROTOC_VERSION=35.1
ARG PROTOC_GEN_GO_VERSION=v1.36.11
ARG PROTOC_GEN_GO_GRPC_VERSION=v1.6.2
ARG BUF_VERSION=v1.71.0
ARG ORAS_VERSION=v1.3.2
ARG GOLANGCI_LINT_VERSION=v2.12.2
ARG GH_CLI_VERSION=2.96.0
ARG HADOLINT_VERSION=2.15.1
ARG FLUX_VERSION=2.9.5
ARG KUSTOMIZE_VERSION=5.8.1
ARG KIND_VERSION=0.33.0
ARG KUBECTL_VERSION=1.37.0
ARG DOCKER_VERSION=29.8.0

# The base image is debian:trixie-slim + `ca-certificates curl git bash`; these are what krayt's
# toolchain needs on top. gcc + libc6-dev are not optional: `go test -race` requires cgo, so
# without a C toolchain the race detector — which CI and every dogfooding task run — fails to
# link. unzip: protoc's release archive is a zip. xz-utils: the Nix installer's tarball is .tar.xz.
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc libc6-dev unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

# The Go toolchain, fetched as the official prebuilt tarball like protoc/gh/hadolint below — the
# base image is an agent image, not a language image, so Go is just another tool this one adds.
# Go's asset arch names ARE Docker's TARGETARCH values verbatim (amd64/arm64), like gh's.
# GO_VERSION must stay >= go.mod's `go` directive: with GOTOOLCHAIN=local (below) a lower one
# fails the build outright rather than silently downloading a second toolchain. Renovate's
# `go version` group bumps this ARG and that directive together (renovate.json).
ARG TARGETARCH
RUN curl -fsSL -o /tmp/go.tar.gz \
      "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" \
 && tar -C /usr/local -xzf /tmp/go.tar.gz \
 && rm /tmp/go.tar.gz

# protoc itself has no Go module (it's the C++ compiler), so it's the one tool fetched as a
# prebuilt release archive; TARGETARCH (declared above) is set per-platform by buildx during the
# multi-arch build.
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) protoc_arch=x86_64 ;; \
      arm64) protoc_arch=aarch_64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/protoc.zip \
      "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-${protoc_arch}.zip" \
 && unzip -q /tmp/protoc.zip -d /usr/local \
 && rm /tmp/protoc.zip \
 && chmod -R a+rX /usr/local/bin/protoc /usr/local/include

# gh CLI, like protoc, has no `go install` story worth relying on, so it's fetched as a prebuilt
# release tarball. Unlike protoc, gh's asset arch names ARE Docker's TARGETARCH values
# (amd64/arm64) verbatim — no x86_64/aarch_64 translation needed. Needed by the
# fix-pr-review-comments task; installing the binary is ALL this image does for it, since gh
# authenticates from the GH_TOKEN the host proxy injects (§6.6.1) and reads that env var itself.
# No entrypoint anywhere touches the token — see README's GH_TOKEN secret.
RUN set -eu; \
    curl -fsSL -o /tmp/gh.tar.gz \
      "https://github.com/cli/cli/releases/download/v${GH_CLI_VERSION}/gh_${GH_CLI_VERSION}_linux_${TARGETARCH}.tar.gz" \
 && tar -xzf /tmp/gh.tar.gz -C /tmp \
 && install -m 0755 "/tmp/gh_${GH_CLI_VERSION}_linux_${TARGETARCH}/bin/gh" /usr/local/bin/gh \
 && rm -rf /tmp/gh.tar.gz "/tmp/gh_${GH_CLI_VERSION}_linux_${TARGETARCH}"

# hadolint lints the agent images' Dockerfiles (see docs/ai-tasks/*.md's verification steps); like
# protoc it ships as a prebuilt release binary (Haskell, no `go install` story), and like protoc its
# arch names aren't Docker's TARGETARCH verbatim.
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) hadolint_arch=x86_64 ;; \
      arm64) hadolint_arch=arm64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/hadolint \
      "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-linux-${hadolint_arch}" \
 && chmod 0755 /usr/local/bin/hadolint

# flux CLI — the GitOps toolkit's client, needed to render and reconcile Flux manifests. Prebuilt
# release tarball like gh, and like gh its asset arch names ARE Docker's TARGETARCH values
# (amd64/arm64) verbatim. FLUX_VERSION carries no leading `v` because that is how the asset name
# spells it; the release tag does, hence the literal `v` in the URL.
RUN set -eu; \
    curl -fsSL -o /tmp/flux.tar.gz \
      "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_${TARGETARCH}.tar.gz" \
 && tar -xzf /tmp/flux.tar.gz -C /tmp flux \
 && install -m 0755 /tmp/flux /usr/local/bin/flux \
 && rm -f /tmp/flux.tar.gz /tmp/flux

# kustomize, the standalone binary rather than `kubectl kustomize` — Flux's build/diff paths shell
# out to it and pin their own version expectations. Arch names are TARGETARCH verbatim; the
# oddity is the release tag, which is monorepo-scoped (`kustomize/v5.8.1`), so the path segment
# needs the `/` percent-encoded as %2F. KUSTOMIZE_VERSION is bare like FLUX_VERSION, and the `v`
# that both the tag and the asset name want is literal in the URL.
RUN set -eu; \
    curl -fsSL -o /tmp/kustomize.tar.gz \
      "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz" \
 && tar -xzf /tmp/kustomize.tar.gz -C /tmp kustomize \
 && install -m 0755 /tmp/kustomize /usr/local/bin/kustomize \
 && rm -f /tmp/kustomize.tar.gz /tmp/kustomize

# kind — throwaway Kubernetes clusters to apply the manifests against. Ships as a bare prebuilt
# binary like hadolint, but unlike hadolint its arch names are TARGETARCH verbatim, so it needs no
# translation case. kind is a client for a container runtime and provides none itself, which is the
# reason this image now ships a daemon and an entrypoint to start it (see entrypoint.sh).
RUN set -eu; \
    curl -fsSL -o /usr/local/bin/kind \
      "https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-${TARGETARCH}" \
 && chmod 0755 /usr/local/bin/kind

# kubectl, without which kind provisions clusters nothing can then talk to. Published by the
# Kubernetes release bucket rather than a GitHub release — the only tool here from that host — as a
# bare binary whose arch names are TARGETARCH verbatim. `stable.txt` in that bucket is the floating
# pointer; KUBECTL_VERSION pins a release out of it so a rebuild cannot silently change minor
# version. Keep it within one minor of the clusters it talks to (kubectl's own skew policy).
RUN set -eu; \
    curl -fsSL -o /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
 && chmod 0755 /usr/local/bin/kubectl

# dockerd's runtime dependencies, which the static bundle below does NOT carry: it ships Go
# binaries only, and dockerd shells out for the rest. iptables is the one that is not optional —
# without it the daemon starts but every bridge network fails to program, which surfaces as kind
# nodes that boot and then cannot reach each other. iproute2 manages the veth pairs, and kmod lets
# dockerd probe for the modules it needs (overlay, br_netfilter) instead of guessing.
RUN apt-get update \
 && apt-get install -y --no-install-recommends iptables iproute2 kmod \
 && rm -rf /var/lib/apt/lists/*

# The docker CLI *and daemon*, from Docker's official static bundle — the one tool here not fetched
# from a GitHub release, and like protoc its arch names are not TARGETARCH verbatim. The whole
# bundle is installed, not just the `docker` client: entrypoint.sh runs a daemon in this container,
# and dockerd is useless without containerd, runc, docker-init and docker-proxy beside it.
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) docker_arch=x86_64 ;; \
      arm64) docker_arch=aarch64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/docker.tgz \
      "https://download.docker.com/linux/static/stable/${docker_arch}/docker-${DOCKER_VERSION}.tgz" \
 && tar -xzf /tmp/docker.tgz -C /tmp docker \
 && install -m 0755 /tmp/docker/* /usr/local/bin/ \
 && rm -rf /tmp/docker.tgz /tmp/docker

# dockerd creates its socket root-owned, group `docker`, mode 0660. Creating that group here and
# putting `agent` in it is what lets the non-root user the agent actually runs as reach the daemon
# root started; entrypoint.sh's `setpriv --init-groups` is the other half, applying this membership
# at handoff. Without both, every `docker` call from the agent is a permission-denied on the socket.
RUN groupadd --system docker \
 && usermod --append --groups docker agent

# Back to the base image's non-root `agent` user for everything below, so it owns its own Go/lint
# caches (see ENV block). The user, its home, and the Claude Code CLI all come from the base.
USER agent
WORKDIR /home/agent

# Agent-owned, writable caches so `go build`, `go test -race`, and `golangci-lint run` work
# under a non-root uid with no permission errors. GOTOOLCHAIN=local matches what the official Go
# image sets: without it, a go.mod naming a newer patch release than GO_VERSION makes `go` fetch a
# whole second toolchain at run time — an egress destination the run's allowlist does not have.
ENV GOPATH=/home/agent/go \
    GOCACHE=/home/agent/.cache/go-build \
    GOMODCACHE=/home/agent/go/pkg/mod \
    GOLANGCI_LINT_CACHE=/home/agent/.cache/golangci-lint \
    GOFLAGS=-mod=mod \
    GOTOOLCHAIN=local \
    PATH="/usr/local/go/bin:/home/agent/go/bin:/home/agent/.local/bin:${PATH}"

# krayt's dev toolchain, pinned by the ARGs above. All installable via `go install`, so one
# command works for both target architectures with no per-arch binary URLs. An agent-owned BuildKit
# cache mount on GOCACHE keeps the compiled objects across rebuilds, so bumping a tool version (or a
# weekly base rebuild) recompiles in seconds, not minutes; the tool binaries land in $GOPATH/bin
# (outside the mount), so they persist into the image.
#
# GOMODCACHE is deliberately NOT mounted: it lives under $GOPATH/pkg, where `go` also writes its
# sumdb cache as a *sibling* dir — a cache mount there leaves that parent root-owned, which the
# non-root `go install` can't write ("open .../pkg/sumdb/...: no such file or directory"). GOCACHE
# (the compile) is the dominant cost anyway.
RUN --mount=type=cache,target=/home/agent/.cache/go-build,uid=1000,gid=1000 \
    go install "github.com/golangci/golangci-lint/v2/cmd/golangci-lint@${GOLANGCI_LINT_VERSION}" \
 && go install "google.golang.org/protobuf/cmd/protoc-gen-go@${PROTOC_GEN_GO_VERSION}" \
 && go install "google.golang.org/grpc/cmd/protoc-gen-go-grpc@${PROTOC_GEN_GO_GRPC_VERSION}" \
 && go install "github.com/bufbuild/buf/cmd/buf@${BUF_VERSION}" \
 && go install "oras.land/oras/cmd/oras@${ORAS_VERSION}"

# Model + reasoning-effort defaults for this image, read by the base entrypoint's optional
# selection branch (those are `claude` flags, and the base is the image that ships `claude`).
# krayt.yaml's `env:` block (§8.1) overrides them per run; the base leaves both unset and lets
# Claude Code pick its own default.
ENV CLAUDE_MODEL=claude-sonnet-5 \
    CLAUDE_EFFORT=high

# /var/lib/docker as a volume, for the reason the official dind image does it: overlay2 refuses to
# stack on the container's own overlayfs, and a volume gives it a normal filesystem. This only
# helps a container runtime — msb ignores VOLUME, and its equivalent is `--root-disk flat:<size>`,
# which mounts ext4 directly instead of the sandbox's OverlayFS (README.md).
VOLUME /var/lib/docker

# start-dockerd is the daemon boot, callable on its own — which is what msb needs, since it runs
# its own init and never uses this ENTRYPOINT (README.md). k8s-entrypoint is the wrapper around it:
# it calls start-dockerd, then drops to `agent` and execs krayt-agent-entrypoint with "$@" intact.
#
# NOTE the USER this lands on is `agent`, set above and deliberately not raised to root here.
# dockerd does need uid 0, so root has to be granted at *run* time by whatever boots the image —
# `user: root` in an msb sandbox config, or `--user 0` for a container runtime — and k8s-entrypoint
# hands the privilege straight back with setpriv. Defaulting the image to root instead would make
# every boot path that resolves the image's own USER (an msb `cmd:`/`scripts:` entry that bypasses
# this ENTRYPOINT) start Claude Code as uid 0, which it refuses outright (§8.2). Entered as
# `agent`, k8s-entrypoint just warns that docker is unavailable and passes through, so the image
# still boots an agent either way — the failure is a missing daemon, not a dead run.
COPY --chmod=0755 start-dockerd /usr/local/bin/start-dockerd
COPY --chmod=0755 entrypoint.sh /usr/local/bin/k8s-entrypoint
ENTRYPOINT ["k8s-entrypoint"]
