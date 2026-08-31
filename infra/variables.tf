variable "region" {
  description = "DigitalOcean region in which to create the server."
  type        = string
  default     = "nyc1"
}

variable "droplet_size" {
  description = "DigitalOcean size slug for the web server."
  type        = string
  default     = "s-1vcpu-1gb-amd"
}

variable "droplet_image" {
  description = "DigitalOcean image slug used to create the server."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "ssh_public_key" {
  description = "Public SSH key authorized for the deploy user and registered with DigitalOcean."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp[0-9]+) ", trimspace(var.ssh_public_key)))
    error_message = "ssh_public_key must be an OpenSSH public key."
  }
}

variable "ssh_source_cidrs" {
  description = "CIDRs allowed to connect over SSH. The default supports local and GitHub-hosted deployment with key-only authentication."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "enable_backups" {
  description = "Enable DigitalOcean weekly Droplet backups."
  type        = bool
  default     = false
}
