output "reserved_ipv4_address" {
  description = "Stable public IPv4 address to use for DNS and deployments."
  value       = digitalocean_reserved_ip.web.ip_address
}

output "droplet_ipv4_address" {
  description = "Droplet's directly assigned IPv4 address. DNS should use the reserved address instead."
  value       = digitalocean_droplet.web.ipv4_address
}

output "droplet_ipv6_address" {
  description = "Droplet IPv6 address. Do not publish an AAAA record until IPv6 has been tested."
  value       = digitalocean_droplet.web.ipv6_address
}

output "ssh_command" {
  description = "Command for connecting to the server after cloud-init completes."
  value       = "ssh deploy@${digitalocean_reserved_ip.web.ip_address}"
}
