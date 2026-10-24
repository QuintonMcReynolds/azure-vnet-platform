# Simulated customer deployment: deploy INTO a VNet the "customer" already owns,
# with the app reachable only from inside their network.
# Create the customer VNet first with scripts/create-customer-vnet.sh.
environment                  = "contoso"
location                     = "eastus2"
existing_vnet_name           = "vnet-contoso-corp"
existing_vnet_resource_group = "rg-contoso-network"
app_subnet_cidr              = "10.60.10.0/27"
db_subnet_cidr               = "10.60.11.0/28"
internal_only                = true
min_replicas                 = 1
max_replicas                 = 5
