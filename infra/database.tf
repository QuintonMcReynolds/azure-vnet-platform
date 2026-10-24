# PostgreSQL with private access only: no public endpoint, reachable from inside the VNet.

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "${local.name}.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "link-${local.name}"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  resource_group_name   = azurerm_resource_group.main.name
  virtual_network_id    = local.vnet_id
  tags                  = local.tags
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                          = "psql-${local.name}-${local.suffix}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  version                       = "16"
  sku_name                      = var.db_sku
  storage_mb                    = 32768
  backup_retention_days         = 7
  delegated_subnet_id           = azurerm_subnet.db.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false
  administrator_login           = "notesadmin"
  administrator_password        = random_password.db.result
  tags                          = local.tags

  lifecycle {
    ignore_changes = [zone]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

resource "azurerm_postgresql_flexible_server_database" "notes" {
  name      = "notes"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_key_vault_secret" "database_url" {
  name         = "database-url"
  key_vault_id = azurerm_key_vault.main.id
  value = format(
    "postgresql+psycopg://%s:%s@%s:5432/%s?sslmode=require",
    azurerm_postgresql_flexible_server.main.administrator_login,
    random_password.db.result,
    azurerm_postgresql_flexible_server.main.fqdn,
    azurerm_postgresql_flexible_server_database.notes.name,
  )
  depends_on = [time_sleep.rbac]
}
