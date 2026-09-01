# Deployment

See the [`operations runbook`](../docs/operations.md) for production cutover,
monitoring, rollback, security, and backup guidance.

## Local Caddy proxy

Run the application and Caddy in separate terminals:

```bash
go run ./cmd/wlls
caddy run --config deploy/Caddyfile
```

Open <http://localhost:3000>. Production environment values switch the site to
`wlls.dev` and redirect `www.wlls.dev` to the apex domain.

## Deploy to DigitalOcean

Provision the Droplet first by following [`../infra/README.md`](../infra/README.md).
The default deployment uses Terraform's Reserved IP and the dedicated SSH key:

```bash
./deploy/deploy.sh
```

An explicit IP or hostname can be supplied while testing:

```bash
./deploy/deploy.sh 203.0.113.10
```

Configuration can also be provided through environment variables:

```text
WLLS_HOST       Server address; overrides the Terraform output
WLLS_SSH_USER   SSH user, defaults to deploy
WLLS_SSH_KEY    Private key, defaults to ~/.ssh/wlls_deploy
WLLS_SSH_PORT   SSH port, defaults to 22
```

The command:

1. Waits for cloud-init and verifies remote Nix.
2. Cross-builds `.#runtime-linux-amd64` locally.
3. Copies the locally built Nix closure over authenticated SSH. Local deployment
   disables Nix signature checks because no binary cache or signing key is
   involved.
4. Atomically activates `/nix/var/nix/profiles/wlls`.
5. Installs the Caddyfile and systemd units.
6. Starts and enables both services.
7. Checks the application on `127.0.0.1:8080/healthz`.
8. Restores the previous runtime if that health check fails.

Caddy may log certificate errors until Cloudflare DNS points `wlls.dev` to the
Reserved IP. It will obtain and renew certificates automatically after cutover.

## Builds

```bash
nix build .#wlls                 # native application
nix build .#runtime              # native application and Caddy
nix build .#runtime-linux-amd64  # Droplet runtime, cross-built locally
```

## Server layout

```text
/nix/var/nix/profiles/wlls  # active runtime and previous generations
/etc/wlls/Caddyfile
/etc/wlls/caddy.env         # optional Caddy overrides
/etc/wlls/wlls.env          # optional application configuration
/var/lib/caddy              # certificates and Caddy state
/var/lib/wlls               # application and future SQLite state
```
