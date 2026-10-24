variable "environment" {
  description = "Deployment name, e.g. dev or a customer name such as contoso."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{2,12}$", var.environment))
    error_message = "Use 2-12 lowercase letters or digits."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus2"
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}

# ---------- Networking ----------
# Default: create a new VNet. Customer mode: set existing_vnet_name and
# existing_vnet_resource_group to deploy into a VNet the customer already owns.

variable "existing_vnet_name" {
  description = "Name of a customer-owned VNet to deploy into. Leave null to create a new VNet."
  type        = string
  default     = null
}

variable "existing_vnet_resource_group" {
  description = "Resource group of the customer-owned VNet."
  type        = string
  default     = null
}

variable "vnet_address_space" {
  description = "Address space when creating a new VNet."
  type        = string
  default     = "10.40.0.0/16"
}

variable "app_subnet_cidr" {
  description = "Subnet for the Container Apps environment (minimum /27)."
  type        = string
  default     = "10.40.0.0/27"
}

variable "db_subnet_cidr" {
  description = "Subnet for PostgreSQL Flexible Server (delegated)."
  type        = string
  default     = "10.40.1.0/28"
}

variable "internal_only" {
  description = "true = app reachable only inside the VNet (typical for customer deployments)."
  type        = bool
  default     = false
}

# ---------- App ----------

variable "deploy_app" {
  description = "Set false on the first pass so the registry exists before an image is pushed."
  type        = bool
  default     = true
}

variable "image_tag" {
  description = "Container image tag to deploy (the pipeline passes the git commit SHA)."
  type        = string
  default     = "latest"
}

variable "min_replicas" {
  type    = number
  default = 1
}

variable "max_replicas" {
  type    = number
  default = 3
}

# ---------- Database ----------

variable "db_sku" {
  description = "PostgreSQL Flexible Server SKU. B_Standard_B1ms is the cheapest."
  type        = string
  default     = "B_Standard_B1ms"
}

# ---------- Monitoring ----------

variable "alert_email" {
  description = "Email that receives alerts. Leave null to skip the action group."
  type        = string
  default     = null
}
