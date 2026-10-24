resource "azurerm_monitor_action_group" "main" {
  count               = var.alert_email == null ? 0 : 1
  name                = "ag-${local.name}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "notes"
  tags                = local.tags

  email_receiver {
    name          = "oncall"
    email_address = var.alert_email
  }
}

# Alert when the API returns server errors.
resource "azurerm_monitor_metric_alert" "http_5xx" {
  count               = var.deploy_app && var.alert_email != null ? 1 : 0
  name                = "alert-${local.name}-5xx"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_container_app.api[0].id]
  description         = "Notes API returned 5xx responses."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5

    dimension {
      name     = "statusCodeCategory"
      operator = "Include"
      values   = ["5xx"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }
}

# Alert when the app keeps restarting (crash loop).
resource "azurerm_monitor_metric_alert" "restarts" {
  count               = var.deploy_app && var.alert_email != null ? 1 : 0
  name                = "alert-${local.name}-restarts"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_container_app.api[0].id]
  description         = "Notes API replicas are restarting."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "RestartCount"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = 3
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }
}
