# Your own sandbox: Terraform creates the VNet and the app is reachable from the internet.
environment        = "dev"
location           = "eastus2"
vnet_address_space = "10.40.0.0/16"
app_subnet_cidr    = "10.40.0.0/27"
db_subnet_cidr     = "10.40.1.0/28"
internal_only      = false
min_replicas       = 1
max_replicas       = 3
