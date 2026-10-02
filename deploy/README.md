# Deployment

See the [`infrastructure runbook`](../infra/README.md) for provisioning and DNS
cutover. The Odin service serves the Markdown blog behind Caddy. The lab is
planned for after the site redesign and code walkthrough.

## Local Caddy proxy

Run the application and Caddy in separate terminals:

```bash
just run
caddy run --config deploy/Caddyfile
```

Open <http://localhost:3000>. Caddy negotiates zstd or gzip for compressible
responses to all methods except HEAD, including Datastar SSE streams on POST,
PATCH, or PUT. Small SSE events start streaming immediately when flushed;
HEAD retains the upstream's uncompressed content length. Images and fonts are
served from the embedded assets. Production environment values switch the site
to `wlls.dev` and redirect `www.wlls.dev` to the apex domain.

For a quick proxy check while both processes are running:

```bash
curl --fail http://localhost:3000/healthz
curl -sD - -o /dev/null -H 'Accept-Encoding: gzip' http://localhost:3000/blog
curl -I --resolve www.localhost:3000:127.0.0.1 http://www.localhost:3000/blog
```

The blog GET response should have `Content-Encoding: gzip`; HEAD keeps its
uncompressed `Content-Length`. The `www.localhost` response should redirect to
`http://localhost:3000/blog`.

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
After cutover, check `/`, `/blog`, a post, and `/healthz` through
`https://wlls.dev`, plus the `https://www.wlls.dev` redirect. A local proxy
check does not exercise Cloudflare, DNS, or certificate issuance.

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
/etc/wlls/wlls.env          # optional app secrets (WLLS_ADMIN_TOKEN)
/var/lib/caddy              # certificates and Caddy state
/var/lib/wlls               # app state: guestbook.db (+ -wal, -shm)
```

## Guestbook and sudo

Approved guestbook entries live in `/var/lib/wlls/guestbook.db` (SQLite, WAL
mode), created on first start. Moderation happens in the site's terminal:
`sudo`, then `pending`, `approve <id>`, `reject <id>`, and `sudo -k`. It needs a
token of 24 or more characters in `/etc/wlls/wlls.env`, readable only by root
(systemd reads it before dropping to the `wlls` user):

```bash
ssh deploy@<droplet> 'umask 077 && openssl rand -base64 32 | sed "s/^/WLLS_ADMIN_TOKEN=/" | sudo tee /etc/wlls/wlls.env >/dev/null && sudo systemctl restart wlls'
ssh deploy@<droplet> 'sudo cat /etc/wlls/wlls.env'   # copy it into your password manager
```

Without the file, `sudo` answers that nobody can, and everything else works.

The Droplet's weekly backups cover the database. For a copy on demand, use
SQLite's online backup, which is safe while the app runs:

```bash
ssh deploy@<droplet> 'sudo nix shell nixpkgs#sqlite -c sqlite3 /var/lib/wlls/guestbook.db ".backup /tmp/guestbook.db"'
```
