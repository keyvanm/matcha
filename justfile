set dotenv-load := true

default:
    @just --list

# ── Linux (Quadlets) ──────────────────────────────────────────────────────────

# Install quadlets and start
activate:
    ./bin/activate

# Stop and remove installed quadlet files
deactivate:
    ./bin/deactivate

# Follow logs for all services
logs:
    journalctl --user -u gitea-tailscale.service -u gitea-server.service -u gitea-backup.service -f

# Show service status
status:
    systemctl --user status gitea-pod.service gitea-tailscale.service gitea-server.service gitea-backup.timer

# ── macOS (Compose) ───────────────────────────────────────────────────────────

# Start via Compose
up:
    podman compose up -d

# Start with local port access for debug
up-local:
    podman compose -f docker-compose.yml -f docker-compose.local.yml up -d

# Stop via Compose
down:
    podman compose down

# ── Admin ─────────────────────────────────────────────────────────────────────

# Create an admin user: just create-admin <username> <email>
create-admin username email:
    ./bin/create-admin {{username}} {{email}}

# ── Backup & Restore ──────────────────────────────────────────────────────────

# Back up Gitea data with restic
backup:
    ./bin/backup

# Restore Gitea data from restic (then: just activate)
restore:
    ./bin/restore
