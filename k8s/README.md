# `k8s` image

A krayt agent image with a Kubernetes/GitOps toolchain on top of
`krayt-agent-claude-code`: `flux`, `kustomize`, `kubectl`, `kind`, and Docker
(client **and** daemon). Published to `ghcr.io/tjololo/krayt-images/k8s` by
[`.github/workflows/k8s-image.yml`](../.github/workflows/k8s-image.yml).

## Architectures

Published as a manifest list covering **`linux/amd64`** and **`linux/arm64`**;
a pull resolves to the right one with no tag suffix. `linux/arm64` is also what
Apple Silicon uses — OCI images have no macOS platform, so Docker Desktop on an
M-series Mac runs the arm64 image in its Linux VM, as does an msb guest there.
Each arch builds on a runner of its own architecture, because the `go install`
layer takes tens of minutes under QEMU emulation.

## Starting the Docker daemon

`kind` is a client for a container runtime and provides none itself, so a daemon
has to be running before it is any use. The image ships
**`start-dockerd`** for that: it starts `dockerd`, blocks until the socket
answers, and exits non-zero with the daemon log if it never does. It is
idempotent, and a no-op when a daemon is already reachable.

Where you call it from depends on how the image is booted, because
**microsandbox does not use the image's `ENTRYPOINT` as the guest's init.** msb
boots its own `agentd` as PID 1 (injected as `init.krun`) and execs the workload
over the agent protocol, so a daemon backgrounded from an exec'd session is a
child of that session rather than of init. Wire it in the sandbox config
instead.

### Under microsandbox (the intended path)

```yaml
# sandbox.yaml
user: "root"                    # dockerd needs uid 0; k8s-entrypoint hands it back
entrypoint: ["k8s-entrypoint"]  # start-dockerd, then setpriv back to `agent`
memory: "2G"
```

```sh
msb run --conf sandbox.yaml --root-disk flat:20G \
  ghcr.io/tjololo/krayt-images/k8s:latest
```

`user: root` is required and `entrypoint:` is what makes the privilege
temporary. The image's own `USER` is `agent` precisely so that a boot path which
resolves the image default instead — an msb `cmd:` or `scripts:` entry that
bypasses the entrypoint — cannot start Claude Code as uid 0, which it refuses
(§8.2). If you would rather wire it as a script, call the same two steps
yourself and keep the drop:

```yaml
user: "root"
scripts:
  start: |
    start-dockerd
    exec setpriv --reuid="$(id -u agent)" --regid="$(id -g agent)" --init-groups \
      -- env HOME=/home/agent krayt-agent-entrypoint
```

Two flags are not optional and cannot be baked into the image:

- **`--root-disk flat:<size>`** — a flat root mounts ext4 directly. On the
  default managed root, Docker's overlay2 layers would sit on top of the
  sandbox's own OverlayFS, which overlay2 refuses. This is the msb equivalent of
  the `VOLUME /var/lib/docker` the Dockerfile declares for container runtimes.
- **`--memory 2G`** or more. Raise it for larger builds.

### Under a container runtime

`ENTRYPOINT` is `k8s-entrypoint`, which calls `start-dockerd`, then drops to
`agent` and execs `krayt-agent-entrypoint` unchanged. Requires `--privileged`
(or `CAP_SYS_ADMIN` plus cgroup write access) for the daemon to set up cgroups,
netfilter, and overlayfs mounts — plus `--user 0`, since the image defaults to
`agent`. `START_DOCKERD=0` skips the daemon; a bind-mounted
`/var/run/docker.sock` is detected and reused, and entering as `agent` degrades
to a warning rather than a failed boot.

## Not included

- **`msb` itself.** This image is a microsandbox *guest*, not a host, so it
  needs no `msb` binary and no `/dev/kvm`.
- **Nested `kind` networking** is untested here; `kind create cluster` pulls
  `kindest/node` from Docker Hub, which the repo's `krayt.yaml` allowlist
  already permits.

## Versions

Tool versions are pinned as `ARG`s at the top of the
[`Dockerfile`](Dockerfile) so they can be bumped independently of the base
image tag. `kubectl` should stay within one minor of the clusters it talks to.
