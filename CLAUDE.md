# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Self-hosted Gitea running as Podman Quadlets (systemd-native), accessible exclusively over Tailscale. Designed for portability: `bin/backup` snapshots Gitea state with restic, and `bin/restore` recovers it on any new host.

## Common Commands

Run `just` to list all available recipes. Key ones:

```bash
just activate       # Linux: install quadlets and start
just deactivate     # Linux: stop and remove installed quadlet files
just logs           # Linux: follow logs for all services
just status         # Linux: show service status

just up             # macOS: start via Compose
just up-local       # macOS: start with local port access for debug (port 3000 web, 2222 SSH)
just down           # macOS: stop via Compose

just create-admin <username> <email>

just backup
just restore
```

### Local debug access (Linux)

Uncomment `PublishPort` lines in [quadlet/matcha.pod](quadlet/matcha.pod), then:
```bash
systemctl --user daemon-reload && systemctl --user restart gitea-pod.service
```

## Architecture

- **Quadlet Pod** ([quadlet/matcha.pod](quadlet/matcha.pod)) defines a shared network namespace for both containers — equivalent to `network_mode: service:tailscale` in Compose.
- **Tailscale sidecar** ([quadlet/gitea-tailscale.container](quadlet/gitea-tailscale.container)) runs inside the pod and owns the network stack. Gitea is unreachable except through Tailscale.
- **HTTPS** is proxied by Tailscale via [tailscale/config/tailscale-serve.json](tailscale/config/tailscale-serve.json) (TLS termination → `localhost:3000`).
- **SSH** (port 22) works automatically — Gitea listens in the shared network namespace, directly reachable on the Tailscale hostname.
- **`~/.local/share/matcha/gitea/`** holds all Gitea state (database, repos, config). Mounted with `:Z,U` for SELinux + unprivileged user mapping.
- **`~/.local/share/matcha/tailscale/`** holds the Tailscale node identity. Not backed up — with a reusable+ephemeral key the node re-registers cleanly on each new host.
- **Daily backup timer** ([quadlet/gitea-backup.timer](quadlet/gitea-backup.timer)) is enabled by `just activate` and runs `bin/backup` via [quadlet/gitea-backup.service](quadlet/gitea-backup.service).

## Environment

Copy `.env.example` to `.env` and fill in all required values:

```bash
TS_AUTHKEY=tskey-auth-...           # reusable + ephemeral key from Tailscale admin panel
GITEA__server__DOMAIN=gitea.your-tailnet.ts.net
GITEA__server__ROOT_URL=https://gitea.your-tailnet.ts.net/
RESTIC_REPOSITORY=/mnt/backup/matcha   # see below for multi-destination
RESTIC_PASSWORD=...
```

Use a **reusable + ephemeral** Tailscale auth key so the node re-registers cleanly on each new host.

## Backup & Restore

`RESTIC_REPOSITORY` supports comma-separated destinations (local, S3, or both):

```bash
RESTIC_REPOSITORY=/mnt/backup/matcha
RESTIC_REPOSITORY=s3:s3.amazonaws.com/my-bucket/matcha
RESTIC_REPOSITORY=/mnt/backup/matcha,s3:s3.amazonaws.com/my-bucket/matcha
```

Initialize each restic repo once before first use:
```bash
restic -r /mnt/backup/matcha init
```

`bin/backup` backs up `~/.local/share/matcha/gitea/` to all configured destinations. `bin/restore` restores from the first destination only.

```bash
just backup
just restore   # then: just activate
```
