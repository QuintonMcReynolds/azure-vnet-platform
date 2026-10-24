resource "azurerm_container_app_environment" "main" {
  name                           = "cae-${local.name}"
  location                       = azurerm_resource_group.main.location
  resource_group_name            = azurerm_resource_group.main.name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id       = azurerm_subnet.app.id
  internal_load_balancer_enabled = var.internal_only
  tags                           = local.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  lifecycle {
    ignore_changes = [infrastructure_resource_group_name]
  }
}

resource "azurerm_container_app" "api" {
  count                        = var.deploy_app ? 1 : 0
  name                         = "ca-${local.name}-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  secret {
    name                = "database-url"
    key_vault_secret_id = azurerm_key_vault_secret.database_url.versionless_id
    identity            = azurerm_user_assigned_identity.app.id
  }

  ingress {
    external_enabled = true # "external" to the environment; still VNet-only when internal_only = true
    target_port      = 8000
    transport        = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "api"
      image  = "${azurerm_container_registry.main.login_server}/notes-api:${var.image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }
      env {
        name  = "APP_VERSION"
        value = var.image_tag
      }
      env {
        name  = "DEPLOY_ENV"
        value = var.environment
      }

      liveness_probe {
        transport = "HTTP"
        path      = "/healthz"
        port      = 8000
      }

      readiness_probe {
        transport = "HTTP"
        path      = "/readyz"
        port      = 8000
      }
    }

    http_scale_rule {
      name                = "http-concurrency"
      concurrent_requests = "50"
    }
  }

  depends_on = [time_sleep.rbac]
}
