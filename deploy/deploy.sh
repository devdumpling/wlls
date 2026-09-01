#!/usr/bin/env bash

set -Eeuo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ssh_user="${WLLS_SSH_USER:-deploy}"
ssh_key="${WLLS_SSH_KEY:-$HOME/.ssh/wlls_deploy}"
ssh_port="${WLLS_SSH_PORT:-22}"
host="${1:-${WLLS_HOST:-}}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
Usage: ./deploy/deploy.sh [host]

Deploy the Linux AMD64 Nix runtime to the Terraform-managed Droplet. If host is
omitted, the command reads the Reserved IP from Terraform output.

Environment:
  WLLS_HOST       Override the Terraform Reserved IP
  WLLS_SSH_USER   SSH user (default: deploy)
  WLLS_SSH_KEY    Private key (default: ~/.ssh/wlls_deploy)
  WLLS_SSH_PORT   SSH port (default: 22)
USAGE
  exit 0
fi

log() {
  printf '\n==> %s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

for command in nix ssh scp; do
  command -v "$command" >/dev/null || fail "required command not found: $command"
done

if [[ -z "$host" ]]; then
  command -v terraform >/dev/null || fail "terraform is required when WLLS_HOST is not set"
  host="$(terraform -chdir="$project_root/infra" output -raw reserved_ipv4_address 2>/dev/null)" ||
    fail "could not read the Reserved IP; pass a host or set WLLS_HOST"
fi

[[ -f "$ssh_key" ]] || fail "SSH private key not found: $ssh_key"
[[ "$ssh_key" != *[\?\&]* ]] || fail "SSH key path cannot contain '?' or '&'"

ssh_target="$ssh_user@$host"
ssh_args=(
  -i "$ssh_key"
  -p "$ssh_port"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
)
scp_args=(
  -i "$ssh_key"
  -P "$ssh_port"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
)

log "Checking $ssh_target"
ssh "${ssh_args[@]}" "$ssh_target" \
  'cloud-init status --wait >/dev/null && test -x /nix/var/nix/profiles/default/bin/nix-daemon'

log "Building Linux AMD64 runtime"
runtime_path="$(nix build \
  "$project_root#runtime-linux-amd64" \
  --no-link \
  --print-out-paths)"
[[ "$runtime_path" == /nix/store/* ]] || fail "unexpected Nix output path: $runtime_path"

log "Copying Nix closure"
remote_store="ssh-ng://$ssh_target:$ssh_port?ssh-key=$ssh_key&remote-program=/nix/var/nix/profiles/default/bin/nix-daemon"
nix copy --no-check-sigs --to "$remote_store" "$runtime_path"

log "Uploading service configuration"
remote_tmp="$(ssh "${ssh_args[@]}" "$ssh_target" 'mktemp -d /tmp/wlls-deploy.XXXXXX')"
scp "${scp_args[@]}" \
  "$project_root/deploy/Caddyfile" \
  "$project_root/deploy/systemd/wlls.service" \
  "$project_root/deploy/systemd/caddy.service" \
  "$ssh_target:$remote_tmp/"

log "Activating runtime and services"
ssh "${ssh_args[@]}" "$ssh_target" bash -s -- "$runtime_path" "$remote_tmp" <<'REMOTE'
set -Eeuo pipefail

runtime_path="$1"
upload_dir="$2"
profile=/nix/var/nix/profiles/wlls
nix_env=/nix/var/nix/profiles/default/bin/nix-env
previous_runtime="$(readlink -f "$profile" 2>/dev/null || true)"

cleanup() {
  rm -rf "$upload_dir"
}
trap cleanup EXIT

rollback() {
  if [[ -n "$previous_runtime" && -e "$previous_runtime" ]]; then
    echo "Application health check failed; restoring $previous_runtime" >&2
    sudo "$nix_env" --profile "$profile" --set "$previous_runtime"
    sudo systemctl restart wlls.service
  fi
}

sudo install -d -m 0755 -o root -g root /etc/wlls
sudo install -m 0644 "$upload_dir/Caddyfile" /etc/wlls/Caddyfile
sudo install -m 0644 "$upload_dir/wlls.service" /etc/systemd/system/wlls.service
sudo install -m 0644 "$upload_dir/caddy.service" /etc/systemd/system/caddy.service
sudo "$nix_env" --profile "$profile" --set "$runtime_path"
sudo systemctl daemon-reload
sudo systemctl enable wlls.service caddy.service >/dev/null
sudo systemctl restart wlls.service

healthy=false
for _ in $(seq 1 20); do
  if curl --fail --silent http://127.0.0.1:8080/healthz >/dev/null 2>&1; then
    healthy=true
    break
  fi
  sleep 0.5
done

if [[ "$healthy" != true ]]; then
  sudo journalctl --unit wlls.service --no-pager --lines 50 >&2 || true
  rollback
  exit 1
fi

sudo env \
    WLLS_SITE_ADDRESS=wlls.dev \
    WLLS_REDIRECT_ADDRESS=www.wlls.dev \
    WLLS_CANONICAL_URL=https://wlls.dev \
    WLLS_UPSTREAM=127.0.0.1:8080 \
    "$profile/bin/caddy" validate --config /etc/wlls/Caddyfile >/dev/null
sudo systemctl restart caddy.service
sudo systemctl is-active --quiet wlls.service caddy.service
REMOTE

log "Deployment healthy at $host"
printf 'DNS cutover target: %s\n' "$host"
