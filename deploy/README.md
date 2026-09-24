# Deployment

See the [`infrastructure runbook`](../infra/README.md) for provisioning and DNS
cutover. The Odin service serves the Markdown blog; the interactive lab and
production-path checks are still in progress before DNS cutover.

## Local Caddy proxy

Run the application and Caddy in separate terminals:

```bash
just run
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
4. Validates the staged Caddyfile with the new runtime.
5. Backs up and promotes the runtime, Caddyfile, and systemd units as one
   release operation.
6. Restarts the Odin service and checks `127.0.0.1:8080/healthz`.
7. Reloads an active Caddy service rather than restarting it.
8. Restores the previous runtime and configuration if activation fails.

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
/var/lib/caddy              # certificates and Caddy state
/var/lib/wlls               # reserved application state (currently empty)
```
