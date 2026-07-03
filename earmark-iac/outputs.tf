output "app_url" {
  description = "Default public URL"
  value       = "https://${fly_app.earmark.name}.fly.dev"
}

output "ipv4" {
  value = fly_ip.v4.address
}

output "ipv6" {
  value = fly_ip.v6.address
}

output "machine_id" {
  value = fly_machine.web.id
}

output "volume_id" {
  value = fly_volume.data.id
}

output "cert_validation" {
  description = "Populated when custom_domain is set — DNS records to create"
  value = var.custom_domain == "" ? null : {
    hostname            = fly_cert.custom[0].hostname
    dnsvalidationtarget = fly_cert.custom[0].dnsvalidationtarget
    dnsvalidationhost   = fly_cert.custom[0].dnsvalidationhostname
  }
}
