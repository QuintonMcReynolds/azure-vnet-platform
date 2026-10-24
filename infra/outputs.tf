output "resource_group" {
  value = azurerm_resource_group.main.name
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "container_app_name" {
  value = var.deploy_app ? azurerm_container_app.api[0].name : null
}

output "app_url" {
  value = var.deploy_app ? "https://${azurerm_container_app.api[0].ingress[0].fqdn}" : null
}

output "internal_only" {
  value = var.internal_only
}

output "vnet_id" {
  value = local.vnet_id
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}
