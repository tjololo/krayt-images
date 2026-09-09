#!/bin/sh
# Container-runtime entrypoint: start the daemon, then hand off to the base image's agent
# entrypoint. This is the `docker run` path into the image.
#
# It is NOT the path microsandbox takes. msb boots its own agentd as the guest's init and execs the
# workload through the agent protocol, so a daemon started here would be a child of an exec'd
# session rather than of init. Under msb, call start-dockerd from the sandbox config instead —
# README.md has the invocation. Everything real lives in start-dockerd; this file only adds the
# privilege handoff that a container needs and a microVM does not.
#
# dockerd needs root while Claude Code refuses uid 0 (§8.2), so this wrapper is the only thing that
# runs as root: it starts the daemon, drops back to `agent`, and execs krayt-agent-entrypoint with
# its arguments untouched, leaving every §8.2 contract intact.
set -eu

log() { echo "[k8s-entrypoint] $*" >&2; }

if [ "${START_DOCKERD:-1}" != 1 ]; then
	log "START_DOCKERD=${START_DOCKERD:-1} — not starting a daemon"
else
	# Deliberately not fatal, unlike start-dockerd's own exit status. Most tasks on this image never
	# touch docker, and killing the agent run over an unusable daemon is worse than letting the
	# agent hear it from `docker` itself; start-dockerd has already explained the failure.
	start-dockerd || log "WARNING: continuing without docker; \`docker\` and \`kind\` will not work"
fi

# Hand off to the base entrypoint. If we are already `agent` — nothing was started above — exec
# straight through; otherwise drop privileges first.
if [ "$(id -u)" = 0 ]; then
	# --init-groups is what places `agent` in the `docker` group created at build time, which is how
	# a non-root uid is permitted to talk to the socket root just created. The uid/gid are resolved
	# from the passwd db rather than hardcoded as 1000, so this survives a base image that renumbers
	# the user. HOME must be set explicitly: docker derived it from USER (= /root) for this process
	# and setpriv does not rewrite it, so without this the agent would look for its config, caches,
	# and credentials in root's home.
	exec setpriv \
		--reuid="$(id -u agent)" --regid="$(id -g agent)" --init-groups \
		-- env HOME=/home/agent krayt-agent-entrypoint "$@"
fi
exec krayt-agent-entrypoint "$@"
