# Deployment

## Local Caddy proxy

Run the Go application in one terminal:

```bash
go run ./cmd/wlls
```

Run Caddy in another:

```bash
caddy run --config deploy/Caddyfile
```

The application is then available through Caddy at <http://localhost:3000>.
`WLLS_SITE_ADDRESS` and `WLLS_UPSTREAM` override those defaults.

## Nix build

Build the native application/runtime, or cross-compile the Linux AMD64 runtime
used by the Droplet:

```bash
nix build .#wlls
nix build .#runtime
nix build .#runtime-linux-amd64
```

The Linux output can be built locally on an Apple Silicon Mac and contains both
Linux `wlls` and Caddy binaries. The server runtime will be installed into the
stable profile path `/nix/var/nix/profiles/wlls`. The systemd units refer to
binaries through that profile, allowing a new Nix generation to be activated
without rewriting the units.

## Server layout

```text
/etc/wlls/Caddyfile
/etc/wlls/caddy.env       # optional Caddy overrides
/etc/wlls/wlls.env        # optional application configuration
/var/lib/caddy            # certificates and Caddy state
/var/lib/wlls             # application and future SQLite state
```

The checked-in units expect dedicated `caddy` and `wlls` system users. Terraform
cloud-init will create the users and directories and install Nix. The separate
deployment command will install the runtime profile and enable the services.

For a staging hostname, write the following on the server before starting
Caddy:

```text
# /etc/wlls/caddy.env
WLLS_SITE_ADDRESS=next.wlls.dev
```
