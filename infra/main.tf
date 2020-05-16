provider "digitalocean" {}

resource "digitalocean_ssh_key" "default" {
  name       = "Default"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "digitalocean_droplet" "discourse" {
  name     = "discourse"
  image    = "discourse-18-04"
  size     = "s-1vcpu-2gb"
  region   = "nyc3"
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]
}

resource "digitalocean_firewall" "fw" {
  name        = "discourse-fw"
  droplet_ids = [digitalocean_droplet.discourse.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "587"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_domain" "domain" {
  name = "alldevopsconsidered.com"
}

resource "digitalocean_record" "discourse" {
  domain = digitalocean_domain.domain.name
  type   = "A"
  name   = "discourse"
  value  = digitalocean_droplet.discourse.ipv4_address
}

resource "digitalocean_record" "spf" {
  domain = digitalocean_domain.domain.name
  type   = "TXT"
  name   = "discourse"
  value  = "v=spf1 include:sendgrid.net ~all"
}

locals {
  # SendGrid DNS validation entries
  sendgrid_cnames = [
    {
      name  = "em4145.discourse"
      value = "u16132719.wl220.sendgrid.net."
    },
    {
      name  = "s1._domainkey.discourse"
      value = "s1.domainkey.u16132719.wl220.sendgrid.net."
    },
    {
      name  = "s2._domainkey.discourse"
      value = "s2.domainkey.u16132719.wl220.sendgrid.net."
    }
  ]
}

resource "digitalocean_record" "sendgrid_cname_records" {
  count = length(local.sendgrid_cnames)

  domain = digitalocean_domain.domain.name
  type   = "CNAME"
  name   = local.sendgrid_cnames[count.index].name
  value  = local.sendgrid_cnames[count.index].value
}

resource "digitalocean_project" "adc" {
  name        = "alldevopsconsidered"
  description = "Resources for ADC (All Devops Considered)"
  purpose     = "Infrastructure"
  environment = "Production"
  resources = [
    digitalocean_droplet.discourse.urn,
    digitalocean_domain.domain.urn,
  ]
}
