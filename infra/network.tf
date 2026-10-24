# Two modes:
#  1. New VNet (default)          -> Terraform creates the VNet.
#  2. Customer VNet ("BYO VNet")  -> Terraform only adds two subnets to a VNet the customer owns,
#                                    the same way a vendor deploys into a customer's VPC.

locals {
  byo_vnet  = var.existing_vnet_name != null
  vnet_id   = local.byo_vnet ? data.azurerm_virtual_network.existing[0].id : azurerm_virtual_network.main[0].id
  vnet_name = local.byo_vnet ? data.azurerm_virtual_network.existing[0].name : azurerm_virtual_network.main[0].name
  vnet_rg   = local.byo_vnet ? var.existing_vnet_resource_group : azurerm_resource_group.main.name
}

data "azurerm_virtual_network" "existing" {
  count               = local.byo_vnet ? 1 : 0
  name                = var.existing_vnet_name
  resource_group_name = var.existing_vnet_resource_group
}

resource "azurerm_virtual_network" "main" {
  count               = local.byo_vnet ? 0 : 1
  name                = "vnet-${local.name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-${local.name}-app"
  resource_group_name  = local.vnet_rg
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.app_subnet_cidr]

  delegation {
    name = "container-apps"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "db" {
  name                 = "snet-${local.name}-db"
  resource_group_name  = local.vnet_rg
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.db_subnet_cidr]

  delegation {
    name = "postgres"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Only the app subnet may talk to the database subnet on 5432.
resource "azurerm_network_security_group" "db" {
  name                = "nsg-${local.name}-db"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  security_rule {
    name                       = "allow-app-to-postgres"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.app_subnet_cidr
    destination_address_prefix = var.db_subnet_cidr
  }

  security_rule {
    name                       = "allow-within-db-subnet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.db_subnet_cidr
    destination_address_prefix = var.db_subnet_cidr
  }

  security_rule {
    name                       = "deny-other-vnet-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}
