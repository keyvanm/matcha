# Matcha

Private Git hosting on your own infrastructure, accessible only over [Tailscale](https://tailscale.com). No public internet exposure, no third-party data custody.

Runs [Gitea](https://gitea.com) in Podman, with Tailscale as a network sidecar that handles authentication, HTTPS (via Tailscale Serve), and SSH — zero extra infra required. Designed to be portable: snapshot with restic, restore on a new host, and everything comes back at the same Tailscale address.

**Good for:**

- Startups and small teams wanting a private GitHub alternative under their own control
- Individuals who want self-hosted Git without exposing anything to the internet

## How it works

Gitea and a Tailscale sidecar run in a shared pod (Podman Quadlets where available, Compose elsewhere). Gitea's network is owned entirely by Tailscale — it's unreachable from anywhere except your tailnet. Tailscale Serve terminates HTTPS and proxies to Gitea on `localhost:3000`. SSH works on port 22 through the same shared network namespace.

All Gitea state lives in `~/.local/share/matcha/gitea/` — a single directory that restic snapshots for backup and restore.

## Prerequisites

- [Podman](https://podman.io/) + [podman-compose](https://github.com/containers/podman-compose) (or Docker + Docker Compose)
- A [Tailscale](https://tailscale.com) account and an auth key — generate one at https://login.tailscale.com/admin/settings/keys (use **reusable + ephemeral** so nodes re-register cleanly on new hosts)
- [restic](https://restic.net) for backup and restore
- [just](https://github.com/casey/just) task runner (optional but recommended)

## Setup

```bash
cp .env.example .env
```

Edit `.env` and fill in all required values:

```bash
TS_AUTHKEY=tskey-auth-...
GITEA__server__DOMAIN=matcha.your-tailnet.ts.net
GITEA__server__ROOT_URL=https://matcha.your-tailnet.ts.net/
RESTIC_REPOSITORY=/mnt/backup/matcha
RESTIC_PASSWORD=your-strong-encryption-password
```

`GITEA__server__DOMAIN` and `GITEA__server__ROOT_URL` are required for Gitea to generate correct clone URLs and suppress configuration warnings.

## Start

**macOS (or any host with Compose):**

```bash
just up
```

**Linux — systemd-native via Podman Quadlets:**

```bash
just activate
```

This installs the Quadlet units, starts the pod, and enables a daily backup timer.

Gitea will be available at `https://matcha.<your-tailnet>.ts.net` once Tailscale connects. SSH git access works on the same hostname at port 22.

## First-time admin

```bash
just create-admin <username> <email>
```

## Backup

`RESTIC_REPOSITORY` supports comma-separated destinations — local path, S3, or both:

```bash
RESTIC_REPOSITORY=/mnt/backup/matcha
RESTIC_REPOSITORY=s3:s3.amazonaws.com/my-bucket/matcha
RESTIC_REPOSITORY=/mnt/backup/matcha,s3:s3.amazonaws.com/my-bucket/matcha
```

Initialize each destination once:

```bash
restic -r /mnt/backup/matcha init
```

Then back up manually, or let the daily timer handle it (Quadlets only):

```bash
just backup
```

Backups briefly stop Gitea for a consistent SQLite snapshot, then restart it automatically.

## Restore / Migrate to a new host

1. Ensure all [prerequisites](#prerequisites) are installed on the new host
2. Clone this repo on the new host
3. Copy `.env` or create one from `.env.example`
4. Restore data:
   ```bash
   just restore
   ```
5. Start:
   ```bash
   just activate   # Linux
   just up         # macOS
   ```

Gitea comes back under the same Tailscale hostname with the full database and all repositories intact.

## Local / Debug access

```bash
just up-local   # macOS: exposes port 3000 (web) and 2222 (SSH) on localhost
```

On Linux, uncomment the `PublishPort` lines in [quadlet/matcha.pod](quadlet/matcha.pod) and reload:

```bash
systemctl --user daemon-reload && systemctl --user restart gitea-pod.service
```

## License

MIT — see [LICENSE](LICENSE).
