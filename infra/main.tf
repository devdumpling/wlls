resource "digitalocean_ssh_key" "deploy" {
  name       = "wlls-deploy"
  public_key = trimspace(var.ssh_public_key)
}

resource "digitalocean_droplet" "web" {
  name              = "wlls-web-1"
  image             = var.droplet_image
  region            = var.region
  size              = var.droplet_size
  ssh_keys          = [digitalocean_ssh_key.deploy.fingerprint]
  monitoring        = true
  ipv6              = true
  backups           = var.enable_backups
  graceful_shutdown = true
  tags              = ["wlls", "web", "production"]

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    ssh_public_key = trimspace(var.ssh_public_key)
  })

  dynamic "backup_policy" {
    for_each = var.enable_backups ? [1] : []
    content {
      plan    = "weekly"
      weekday = "SUN"
      hour    = 8
    }
  }
}

resource "digitalocean_reserved_ip" "web" {
  region = var.region
}

resource "digitalocean_reserved_ip_assignment" "web" {
  ip_address = digitalocean_reserved_ip.web.ip_address
  droplet_id = digitalocean_droplet.web.id
}

resource "digitalocean_project" "wlls" {
  name        = "wlls.dev"
  description = "Personal site and web experiments."
  purpose     = "Website or blog"
  environment = "Production"
  resources = [
    digitalocean_droplet.web.urn,
    digitalocean_reserved_ip.web.urn,
  ]
}
