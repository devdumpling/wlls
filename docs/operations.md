# Operations runbook

## System model

```text
Cloudflare DNS ──► DigitalOcean Reserved IP ──► Caddy ──► Go on 127.0.0.1:8080
```

- **Terraform** owns DigitalOcean resources.
- **cloud-init** bootstraps a new Droplet once.
- **Nix** builds the Go and Caddy runtime.
- **`deploy/deploy.sh`** transfers and activates releases.
- **systemd** runs and restarts Go and Caddy.
- **Caddy** provides TLS, HTTP/2, HTTP/3, compression, and reverse proxying.
- **Cloudflare** remains the registrar, authoritative DNS provider, and home of
  the email records. Web records are DNS-only.

## Before production cutover

If cutover is not imminent, stop Caddy to avoid unnecessary certificate retries:

```bash
IP="$(terraform -chdir=infra output -raw reserved_ipv4_address)"
ssh -i ~/.ssh/wlls_deploy deploy@"$IP" 'sudo systemctl stop caddy.service'
```

Confirm Terraform has no unexpected changes:

```bash
terraform -chdir=infra plan
```

Protect `infra/terraform.tfstate`. It is ignored by Git and must be backed up
securely until it is migrated to a remote backend.

## Deploy a release

```bash
./deploy/deploy.sh
```

The command builds Linux AMD64 locally, copies the Nix closure over authenticated
SSH, activates the remote profile, installs configuration, restarts services,
and checks the application health endpoint. It restores the previous runtime if
the application health check fails.

A dirty Git tree warning from Nix is informational, but production releases
should normally come from committed source.

## Cut over DNS

In Cloudflare, replace only the web records:

```text
Type   Name   Value                 Proxy
A      @      <Reserved IPv4>       DNS only
CNAME  www    wlls.dev              DNS only
```

Remove conflicting web records and stale AAAA records. Do not alter MX, SPF,
DKIM, DMARC, or email-provider verification records.

Wait for the apex to resolve to the Reserved IP:

```bash
dig +short wlls.dev
```

Then start Caddy and watch certificate issuance:

```bash
ssh -i ~/.ssh/wlls_deploy deploy@"$IP" \
  'sudo systemctl restart caddy.service'

ssh -i ~/.ssh/wlls_deploy deploy@"$IP" \
  'sudo journalctl -u caddy.service -f'
```

Verify:

```bash
curl -I https://wlls.dev
curl https://wlls.dev/healthz
dig MX wlls.dev
```

Keep the old Cloudflare-hosted application available briefly as a DNS rollback
target.

## Routine operations

```bash
# Service status
sudo systemctl status wlls.service caddy.service

# Follow logs
sudo journalctl -u wlls.service -f
sudo journalctl -u caddy.service -f

# Recent logs
sudo journalctl -u wlls.service --since today --no-pager

# Machine resources
free -h
df -h
systemd-cgtop

# Local application health from the server
curl --fail http://127.0.0.1:8080/healthz

# Nix deployment generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/wlls
```

DigitalOcean monitoring is enabled. Add CPU, memory, disk, and external uptime
alerts after cutover.

## Reboot test

After the first successful cutover:

```bash
ssh -i ~/.ssh/wlls_deploy deploy@"$IP" 'sudo reboot'
```

Once SSH returns:

```bash
ssh -i ~/.ssh/wlls_deploy deploy@"$IP" \
  'sudo systemctl is-active wlls.service caddy.service'

curl https://wlls.dev/healthz
```

## Rollback

The deployment command automatically rolls back when the new Go service fails
its local health check. To roll back manually:

```bash
ssh -i ~/.ssh/wlls_deploy deploy@"$IP"
sudo nix-env --rollback --profile /nix/var/nix/profiles/wlls
sudo systemctl restart wlls.service caddy.service
```

If the entire origin is unhealthy, point the Cloudflare web records back to the
old deployment while investigating.

## Terraform rules

- Run `terraform plan` before every infrastructure change.
- Save reviewed plans with `-out=tfplan` when appropriate; delete them after use.
- Never commit state, plans, tokens, or private keys.
- Avoid changing Terraform-managed resources manually in DigitalOcean.
- Import existing resources if state is ever lost; do not recreate them blindly.
- Changes to cloud-init replace the Droplet because user data runs only at first
  boot.
- The Reserved IPv4 is stable across Droplet replacements; the direct IPv4 and
  IPv6 addresses are not.
- Migrate state to a remote backend before Terraform runs in GitHub Actions.

## Security notes

- Root SSH and password authentication are disabled.
- SSH is currently open to the internet for local and GitHub-hosted deployments,
  but only key authentication is accepted. Restrict it later if a stable runner,
  VPN, or temporary firewall workflow is introduced.
- Keep `~/.ssh/wlls_deploy` backed up securely and never store it in Git.
- Local Nix deployment disables closure signature checking because artifacts are
  transferred directly over authenticated SSH. A shared binary cache should use
  signing keys.
- Remove shell credentials when finished:

  ```bash
  unset DIGITALOCEAN_TOKEN TF_VAR_ssh_public_key
  ```

## Backups and persistent data

The current application is reproducible from Git and contains no unique server
data. Caddy certificates can be regenerated.

Before SQLite stores unique data:

1. Enable a tested, application-aware SQLite backup process.
2. Copy backups off the Droplet.
3. Test restoration.
4. Consider enabling DigitalOcean weekly backups as an additional layer, not the
   only backup.

Never copy an active SQLite database naively when WAL mode is enabled. Use the
SQLite backup API, `VACUUM INTO`, or a tool designed for SQLite replication.

## Maintenance trajectory

1. Complete the application rewrite and production cutover.
2. Migrate Terraform state to a remote backend.
3. Add external uptime and DigitalOcean resource alerts.
4. Add GitHub Actions for tests and application deployment.
5. Keep Terraform apply separate and manually approved.
6. Add SQLite backups before persistent features.
7. Periodically prune old Nix generations after retaining known-good rollbacks.

The infrastructure is intentionally small: one replaceable server, one stable
Reserved IP, one reproducible runtime, and no application data hidden in the
machine.
