# Infrastructure runbook

The site runs as a Go service behind Caddy on one DigitalOcean Droplet.
Terraform owns the DigitalOcean resources; cloud-init bootstraps the machine;
Nix builds and installs the runtime.

Cloudflare will remain the registrar, authoritative DNS provider, and home of
the existing email records. Web records will be **DNS only**, so HTTP traffic
goes directly to DigitalOcean rather than through Cloudflare's proxy.

## What Terraform creates

- DigitalOcean Project
- Premium AMD 1 vCPU / 1 GB Ubuntu Droplet in `nyc1`
- Reserved IPv4 address
- Cloud Firewall for SSH, HTTP, HTTPS, and HTTP/3
- Deployment SSH key
- Monitoring and IPv6
- Optional weekly backups

Cloud-init creates the `deploy`, `wlls`, and `caddy` users, disables password and
root SSH, adds 1 GB of swap, installs Nix, and enables flakes. It does not deploy
the application.

## 1. Prepare local credentials

Create a dedicated SSH key:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/wlls_deploy -C "wlls.dev deployment"
```

Create a read/write API token in DigitalOcean, then export credentials:

```bash
export DIGITALOCEAN_TOKEN="..."
export TF_VAR_ssh_public_key="$(cat ~/.ssh/wlls_deploy.pub)"
```

Keep the token and private key out of the repository.

## 2. Provision DigitalOcean

```bash
terraform -chdir=infra init
terraform -chdir=infra validate
terraform -chdir=infra plan
terraform -chdir=infra apply
```

Review the plan before applying. Charges begin when the Droplet is created.
Terraform should create six resources.

Get the stable Reserved IP and wait for cloud-init:

```bash
IP="$(terraform -chdir=infra output -raw reserved_ipv4_address)"

ssh \
  -i ~/.ssh/wlls_deploy \
  -o StrictHostKeyChecking=accept-new \
  deploy@"$IP" \
  'cloud-init status --wait'
```

If bootstrap fails:

```bash
ssh -i ~/.ssh/wlls_deploy deploy@"$IP"
sudo cloud-init status --long
sudo tail -n 200 /var/log/cloud-init-output.log
```

Always use the Reserved IPv4 for DNS and deployment. Do not publish the IPv6
address until it has been tested; it is tied to the Droplet rather than the
Reserved IP.

## 3. Deploy the application

Terraform leaves an initialized but empty server. The deployment process will:

1. Build `.#runtime-linux-amd64` locally.
2. Copy the Nix closure to the Droplet.
3. Activate `/nix/var/nix/profiles/wlls`.
4. Install the Caddyfile and systemd units.
5. Start `wlls.service` and `caddy.service`.
6. Check `/healthz` through the Reserved IP or domain.

See [`../deploy/README.md`](../deploy/README.md), then run:

```bash
./deploy/deploy.sh
```

## 4. Cut over `wlls.dev`

After the application and Caddy are running, change only the web records in
Cloudflare DNS:

```text
Type   Name   Value                 Proxy
A      @      <Reserved IPv4>       DNS only
CNAME  www    wlls.dev              DNS only
```

Replace conflicting existing apex or `www` web records. Do not add an AAAA
record yet.

Leave all email records unchanged, including MX, SPF, DKIM, DMARC, and provider
verification records. Cloudflare remains authoritative for them.

Caddy will obtain production TLS certificates after DNS points to the Droplet.
Some downtime during propagation and certificate issuance is acceptable.

Verify the cutover:

```bash
dig +short wlls.dev
dig MX wlls.dev
curl -I https://wlls.dev
curl https://wlls.dev/healthz
```

The first command should return the Reserved IPv4. In Cloudflare, both web
records must show the gray **DNS only** cloud. Cloudflare will answer DNS queries
but will not carry, cache, or inspect web traffic.

## Terraform state

The initial workflow uses local state under `infra/`. It is ignored by Git but
must be backed up and treated as sensitive. Before GitHub Actions can deploy or
manage infrastructure, migrate it to a remote backend such as HCP Terraform:

```bash
terraform -chdir=infra init -migrate-state
```

Do not recreate resources manually if state is lost. Restore the state or import
the existing resources first.
