data "cloudflare_zone" "site" {
  filter = {
    name = var.zone_name
  }
}

locals {
  zone_id = data.cloudflare_zone.site.zone_id
}

# Only settings the application depends on live here. DNS (including the
# email records) stays in the dashboard; see ../README.md.
locals {
  zone_settings = {
    # Caddy terminates Cloudflare-to-origin TLS with a real certificate.
    ssl              = "strict"
    always_use_https = "on"
    min_tls_version  = "1.2"
    http3            = "on"

    # Features that rewrite HTML make Cloudflare drop the origin's ETag, so
    # browsers could not revalidate pages. The site needs none of them, and
    # an inline script injected by any of them would also violate the CSP.
    automatic_https_rewrites = "off"
    email_obfuscation        = "off"
    rocket_loader            = "off"
  }
}

resource "cloudflare_zone_setting" "site" {
  for_each = local.zone_settings

  zone_id    = local.zone_id
  setting_id = each.key
  value      = each.value
}

# Cloudflare asks the origin for gzip or br, never zstd, so Caddy sends it
# identity and Cloudflare compresses per visitor (deploy/Caddyfile). Its
# default content types exclude Server-Sent Events; this rule adds them. The
# name matches the dashboard-created ruleset, since renaming forces replacement.
resource "cloudflare_ruleset" "compression" {
  zone_id     = local.zone_id
  name        = "default"
  description = "Compress Datastar SSE streams; zstd first."
  kind        = "zone"
  phase       = "http_response_compression"
  rules = [
    {
      description = "Compress Server-Sent Events"
      expression  = "http.response.content_type.media_type eq \"text/event-stream\""
      action      = "compress_response"
      action_parameters = {
        algorithms = [
          { name = "zstd" },
          { name = "brotli" },
        ]
      }
    },
  ]
}
