# Container registry + Key Vault. The app pulls images and reads secrets with its
# managed identity, so no passwords or registry keys are stored in the pipeline.

resource "azurerm_container_registry" "main" {
  name                = "acrnotes${var.environment}${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

resource "azurerm_role_assignment" "app_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

resource "azurerm_key_vault" "main" {
  name                       = "kv-notes-${var.environment}-${local.suffix}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  tags                       = local.tags
}

# The identity running Terraform (the pipeline) writes secrets.
resource "azurerm_role_assignment" "deployer_kv_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# The app only reads secrets.
resource "azurerm_role_assignment" "app_kv_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# Azure RBAC can take a minute to propagate.
resource "time_sleep" "rbac" {
  depends_on      = [azurerm_role_assignment.deployer_kv_officer, azurerm_role_assignment.app_kv_reader, azurerm_role_assignment.app_acr_pull]
  create_duration = "60s"
}
