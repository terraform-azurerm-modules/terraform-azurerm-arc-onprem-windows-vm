output "fqdn" {
  value = var.public_ip ? azurerm_public_ip.onprem["pip"].fqdn : null
}

output "public_ip_address" {
  value = var.public_ip ? azurerm_public_ip.onprem["pip"].ip_address : null
}
