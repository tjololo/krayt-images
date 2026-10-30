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
FROM ghcr.io/418-cloud/krayt-agent-claude-code:2.1.309

# Tool versions, pinned so Renovate's custom regex manager (renovate.json) can bump them
# independently of the base image tag. `make proto` (Nix) stays the source of truth for the
# *committed* generated code; this toolchain is only for an agent regenerating it mid-run
# (see proto-direct.sh) when it edits internal/protocol/krayt.proto.
# renovate: datasource=golang-version depName=go
ARG GO_VERSION=1.26.3
# renovate: datasource=github-releases depName=protocolbuffers/protobuf extractVersion=^v(?<version>.*)$
ARG PROTOC_VERSION=35.1
# renovate: datasource=go depName=google.golang.org/protobuf
ARG PROTOC_GEN_GO_VERSION=v1.36.11
# renovate: datasource=go depName=google.golang.org/grpc/cmd/protoc-gen-go-grpc
ARG PROTOC_GEN_GO_GRPC_VERSION=v1.6.2
# renovate: datasource=go depName=github.com/bufbuild/buf
ARG BUF_VERSION=v1.71.0
# renovate: datasource=go depName=oras.land/oras
ARG ORAS_VERSION=v1.3.2
# renovate: datasource=go depName=github.com/golangci/golangci-lint/v2
ARG GOLANGCI_LINT_VERSION=v2.15.0
# renovate: datasource=github-releases depName=cli/cli extractVersion=^v(?<version>.*)$
ARG GH_CLI_VERSION=2.96.0
# renovate: datasource=github-releases depName=hadolint/hadolint extractVersion=^v(?<version>.*)$
ARG HADOLINT_VERSION=2.15.1
# renovate: datasource=github-releases depName=fluxcd/flux2 extractVersion=^v(?<version>.*)$
ARG FLUX_VERSION=2.9.5
# renovate: datasource=github-releases depName=kubernetes-sigs/kustomize extractVersion=^kustomize/v(?<version>.*)$
ARG KUSTOMIZE_VERSION=5.8.1
# renovate: datasource=github-releases depName=kubernetes-sigs/kind extractVersion=^v(?<version>.*)$
ARG KIND_VERSION=0.33.0
# renovate: datasource=github-releases depName=kubernetes/kubernetes extractVersion=^v(?<version>.*)$
ARG KUBECTL_VERSION=1.37.0
# renovate: datasource=github-releases depName=moby/moby extractVersion=^docker-v(?<version>.*)$
ARG DOCKER_VERSION=29.8.0
# Operator (kubebuilder) toolchain. ENVTEST_K8S_VERSION tracks KUBECTL_VERSION, and both track the
# k8s.io/api minor that KUBEBUILDER_VERSION scaffolds into a new project's go.mod.
# renovate: datasource=github-releases depName=kubernetes-sigs/kubebuilder extractVersion=^v(?<version>.*)$
ARG KUBEBUILDER_VERSION=4.16.0
# renovate: datasource=go depName=sigs.k8s.io/controller-tools
ARG CONTROLLER_TOOLS_VERSION=v0.23.0
# renovate: datasource=go depName=sigs.k8s.io/controller-runtime/tools/setup-envtest
ARG SETUP_ENVTEST_VERSION=v0.25.2
# renovate: datasource=github-releases depName=kubernetes/kubernetes extractVersion=^v(?<version>.*)$
ARG ENVTEST_K8S_VERSION=1.37.0
# renovate: datasource=go depName=github.com/onsi/ginkgo/v2
ARG GINKGO_VERSION=v2.33.1
# renovate: datasource=go depName=go.uber.org/mock
ARG MOCKGEN_VERSION=v0.6.0
# renovate: datasource=go depName=gotest.tools/gotestsum
ARG GOTESTSUM_VERSION=v1.13.0
# renovate: datasource=go depName=github.com/go-delve/delve
ARG DELVE_VERSION=v1.27.2
# renovate: datasource=go depName=golang.org/x/vuln
ARG GOVULNCHECK_VERSION=v1.9.0
# renovate: datasource=go depName=golang.org/x/tools
ARG GOIMPORTS_VERSION=v0.52.0
# renovate: datasource=go depName=mvdan.cc/gofumpt
ARG GOFUMPT_VERSION=v0.12.0
# renovate: datasource=go depName=mvdan.cc/sh/v3
ARG SHFMT_VERSION=v3.14.1
# renovate: datasource=go depName=github.com/elastic/crd-ref-docs
ARG CRD_REF_DOCS_VERSION=v0.3.0
# renovate: datasource=github-releases depName=helm/helm extractVersion=^v(?<version>.*)$
ARG HELM_VERSION=4.3.1
# renovate: datasource=github-releases depName=docker/buildx extractVersion=^v(?<version>.*)$
ARG BUILDX_VERSION=0.38.1
# renovate: datasource=github-releases depName=yannh/kubeconform extractVersion=^v(?<version>.*)$
ARG KUBECONFORM_VERSION=0.8.0
# renovate: datasource=github-releases depName=stackrox/kube-linter extractVersion=^v(?<version>.*)$
ARG KUBE_LINTER_VERSION=0.8.3
# renovate: datasource=github-releases depName=kyverno/chainsaw extractVersion=^v(?<version>.*)$
ARG CHAINSAW_VERSION=0.2.15
# renovate: datasource=github-releases depName=aquasecurity/trivy extractVersion=^v(?<version>.*)$
ARG TRIVY_VERSION=0.76.1
# renovate: datasource=github-releases depName=mikefarah/yq extractVersion=^v(?<version>.*)$
ARG YQ_VERSION=4.54.1
# renovate: datasource=github-releases depName=hashicorp/terraform extractVersion=^v(?<version>.*)$
ARG TERRAFORM_VERSION=1.17.1
# renovate: datasource=github-releases depName=terraform-linters/tflint extractVersion=^v(?<version>.*)$
ARG TFLINT_VERSION=0.65.0

# The base image is debian:trixie-slim + `ca-certificates curl git bash`; these are what krayt's
# toolchain needs on top. gcc + libc6-dev are not optional: `go test -race` requires cgo, so
# without a C toolchain the race detector — which CI and every dogfooding task run — fails to
# link. unzip: protoc's release archive is a zip. xz-utils: the Nix installer's tarball is .tar.xz.
# make: every kubebuilder project is driven through its scaffolded Makefile (`make generate
# manifests test lint`), and the base has no make. jq for JSON in scripts and Makefiles.
# shellcheck and yamllint lint the hack/ scripts and the YAML under config/ — both are distro
# packages with no release cadence worth pinning separately.
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc libc6-dev unzip xz-utils \
      make jq shellcheck yamllint \
 && rm -rf /var/lib/apt/lists/*

# The Go toolchain, fetched as the official prebuilt tarball like protoc/gh/hadolint below — the
# base image is an agent image, not a language image, so Go is just another tool this one adds.
# Go's asset arch names ARE Docker's TARGETARCH values verbatim (amd64/arm64), like gh's.
# GO_VERSION must stay >= go.mod's `go` directive: with GOTOOLCHAIN=local (below) a lower one
# fails the build outright rather than silently downloading a second toolchain. That holds for the
# `go install`ed tools below too: a tool bump whose go.mod needs a newer Go fails here until
# Renovate's golang-version PR for this ARG lands first.
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

# docker buildx, as a CLI plugin: the static bundle above ships the classic builder only, and
# kubebuilder's scaffolded `make docker-buildx` (the multi-arch manager image) calls `docker buildx`.
# A bare binary with TARGETARCH arch names; /usr/local/lib/docker/cli-plugins is on the CLI's
# system-wide plugin search path, so every user picks it up without a ~/.docker of its own.
RUN set -eu; \
    mkdir -p /usr/local/lib/docker/cli-plugins; \
    curl -fsSL -o /usr/local/lib/docker/cli-plugins/docker-buildx \
      "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-${TARGETARCH}" \
 && chmod 0755 /usr/local/lib/docker/cli-plugins/docker-buildx

# kubebuilder itself — scaffolds projects, APIs, webhooks and plugins (`kubebuilder init`,
# `create api`, `create webhook`, `edit --plugins helm/v2-alpha`). Bare binary, TARGETARCH names.
RUN set -eu; \
    curl -fsSL -o /usr/local/bin/kubebuilder \
      "https://github.com/kubernetes-sigs/kubebuilder/releases/download/v${KUBEBUILDER_VERSION}/kubebuilder_linux_${TARGETARCH}" \
 && chmod 0755 /usr/local/bin/kubebuilder

# helm, for the chart kubebuilder's helm plugin generates under dist/chart (`helm lint`,
# `helm template`, installing it into kind). Served from get.helm.sh, not the GitHub release, which
# carries no binaries; arch names are TARGETARCH verbatim, inside a linux-<arch>/ directory.
RUN set -eu; \
    curl -fsSL -o /tmp/helm.tar.gz \
      "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
 && tar -xzf /tmp/helm.tar.gz -C /tmp "linux-${TARGETARCH}/helm" \
 && install -m 0755 "/tmp/linux-${TARGETARCH}/helm" /usr/local/bin/helm \
 && rm -rf /tmp/helm.tar.gz "/tmp/linux-${TARGETARCH}"

# kubeconform validates rendered manifests (`kustomize build config/default | kubeconform`) against
# the upstream schemas, and against the operator's own CRDs once converted to JSON schema.
RUN set -eu; \
    curl -fsSL -o /tmp/kubeconform.tar.gz \
      "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-${TARGETARCH}.tar.gz" \
 && tar -xzf /tmp/kubeconform.tar.gz -C /tmp kubeconform \
 && install -m 0755 /tmp/kubeconform /usr/local/bin/kubeconform \
 && rm -f /tmp/kubeconform.tar.gz /tmp/kubeconform

# kube-linter checks the same manifests for security and reliability problems (privileged
# containers, missing probes and limits, RBAC wildcards) — kubeconform checks shape, this checks
# judgement. Bare binary whose amd64 asset carries no arch suffix at all.
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) kube_linter_asset=kube-linter-linux ;; \
      arm64) kube_linter_asset=kube-linter-linux_arm64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/kube-linter \
      "https://github.com/stackrox/kube-linter/releases/download/v${KUBE_LINTER_VERSION}/${kube_linter_asset}" \
 && chmod 0755 /usr/local/bin/kube-linter

# chainsaw — declarative end-to-end tests for operators (apply, assert on status, clean up),
# run against a kind cluster as a complement to kubebuilder's Ginkgo-based test/e2e suite.
RUN set -eu; \
    curl -fsSL -o /tmp/chainsaw.tar.gz \
      "https://github.com/kyverno/chainsaw/releases/download/v${CHAINSAW_VERSION}/chainsaw_linux_${TARGETARCH}.tar.gz" \
 && tar -xzf /tmp/chainsaw.tar.gz -C /tmp chainsaw \
 && install -m 0755 /tmp/chainsaw /usr/local/bin/chainsaw \
 && rm -f /tmp/chainsaw.tar.gz /tmp/chainsaw

# trivy scans the manager image, the Go module graph, and the rendered manifests (`trivy image`,
# `trivy fs`, `trivy config`) and emits SBOMs. Arch names are its own (64bit/ARM64).
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) trivy_arch=64bit ;; \
      arm64) trivy_arch=ARM64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/trivy.tar.gz \
      "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${trivy_arch}.tar.gz" \
 && tar -xzf /tmp/trivy.tar.gz -C /tmp trivy \
 && install -m 0755 /tmp/trivy /usr/local/bin/trivy \
 && rm -f /tmp/trivy.tar.gz /tmp/trivy

# yq, for editing the YAML under config/ in place (kustomizations, patches, CRD samples) the way
# jq does JSON. Bare binary, TARGETARCH names.
RUN set -eu; \
    curl -fsSL -o /usr/local/bin/yq \
      "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH}" \
 && chmod 0755 /usr/local/bin/yq

# Terraform includes fmt, validate, and the native test runner. Both release archives use
# TARGETARCH verbatim; verify the selected archive against the upstream checksum manifest.
RUN set -eu; \
    mkdir -p /tmp/terraform; \
    cd /tmp/terraform; \
    curl -fsSL -o terraform.zip \
      "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" \
 && curl -fsSL -o checksums.txt \
      "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
 && grep " terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}\\.zip$" checksums.txt \
      | sed 's/terraform_.*\.zip$/terraform.zip/' | sha256sum -c - \
 && unzip -q terraform.zip terraform \
 && install -m 0755 terraform /usr/local/bin/terraform \
 && rm -rf /tmp/terraform

# TFLint ships its Terraform ruleset in the binary; provider-specific plugins are project-owned.
RUN set -eu; \
    mkdir -p /tmp/tflint; \
    cd /tmp/tflint; \
    curl -fsSL -o tflint.zip \
      "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${TARGETARCH}.zip" \
 && curl -fsSL -o checksums.txt \
      "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/checksums.txt" \
 && grep " tflint_linux_${TARGETARCH}\\.zip$" checksums.txt \
      | sed 's/tflint_linux_.*\.zip$/tflint.zip/' | sha256sum -c - \
 && unzip -q tflint.zip tflint \
 && install -m 0755 tflint /usr/local/bin/tflint \
 && rm -rf /tmp/tflint

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

# The operator toolchain that installs the same way: controller-gen (CRDs, RBAC, webhooks,
# DeepCopy), setup-envtest, the ginkgo CLI (kubebuilder's test/e2e suite is Ginkgo), mockgen,
# gotestsum, delve, govulncheck, the formatters golangci-lint's own `fmt` doesn't replace for
# editor-style use (goimports, gofumpt, shfmt), and crd-ref-docs for API reference docs. A
# scaffolded Makefile still `go install`s its own pinned controller-gen/setup-envtest/golangci-lint
# into ./bin; these are for running them directly, and they share this layer's warm GOCACHE.
RUN --mount=type=cache,target=/home/agent/.cache/go-build,uid=1000,gid=1000 \
    go install "sigs.k8s.io/controller-tools/cmd/controller-gen@${CONTROLLER_TOOLS_VERSION}" \
 && go install "sigs.k8s.io/controller-runtime/tools/setup-envtest@${SETUP_ENVTEST_VERSION}" \
 && go install "github.com/onsi/ginkgo/v2/ginkgo@${GINKGO_VERSION}" \
 && go install "go.uber.org/mock/mockgen@${MOCKGEN_VERSION}" \
 && go install "gotest.tools/gotestsum@${GOTESTSUM_VERSION}" \
 && go install "github.com/go-delve/delve/cmd/dlv@${DELVE_VERSION}" \
 && go install "golang.org/x/vuln/cmd/govulncheck@${GOVULNCHECK_VERSION}" \
 && go install "golang.org/x/tools/cmd/goimports@${GOIMPORTS_VERSION}" \
 && go install "mvdan.cc/gofumpt@${GOFUMPT_VERSION}" \
 && go install "mvdan.cc/sh/v3/cmd/shfmt@${SHFMT_VERSION}" \
 && go install "github.com/elastic/crd-ref-docs@${CRD_REF_DOCS_VERSION}"

# envtest's kube-apiserver + etcd, fetched at build time into setup-envtest's default store
# (~/.local/share/kubebuilder-envtest). setup-envtest downloads them from GitHub release assets,
# which redirect to a host krayt.yaml's allowlist does not carry, so a run cannot fetch them
# itself. The `current` symlink gives KUBEBUILDER_ASSETS (ENV below) one arch-independent path for
# a bare `go test ./...` or `ginkgo`. The scaffolded `make test` ignores it — it resolves its own
# from ./bin/k8s — so README.md shows how to point that at this store instead.
RUN set -eu; \
    assets="$(setup-envtest use "${ENVTEST_K8S_VERSION}" -p path)"; \
    ln -s "${assets}" /home/agent/.local/share/kubebuilder-envtest/current
ENV KUBEBUILDER_ASSETS=/home/agent/.local/share/kubebuilder-envtest/current

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
