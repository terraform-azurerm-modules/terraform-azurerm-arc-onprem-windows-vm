variable "name" {
  description = "Hostname for the VM."
  type        = string
}

variable "subnet_id" {
  description = "Resource ID for a subnet."
  type        = string
}

variable "asg_id" {
  description = "Optional resource ID for an application security group"
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "Name for the resource group. Required."
  type        = string
  default     = "onprem_servers"
}

//=============================================================

variable "size" {
  description = "Azure virtual machine size."
  default     = "Standard_D2s_v3"
}

variable "location" {
  description = "Azure region for the on prem VM."
  default     = "UK South"
}

variable "tags" {
  description = "Map of tags for the resources created by this module. Use arc.tags for the Arc Connected Server tags if onboarding."
  type        = map(string)
  default     = {}
}

//=============================================================

variable "azcmagent" {
  description = "Set to true to download the azcmagent. Is automatically set to true if the arc object is set."
  type        = bool
  default     = false
}

variable "arc" {
  description = "Object describing the service principal and resource group for the Azure Arc connected machines. Requires azcmagent = true."
  type = object({
    tenant_id                = string
    subscription_id          = string
    service_principal_appid  = string
    service_principal_secret = string
    resource_group_name      = string
    location                 = string
    tags                     = map(string)
  })

  default = null
}


//=============================================================

variable "admin_username" {
  default = "onpremadmin"
}

variable "admin_password" {
  description = "Administrator password. Derived from the pet secret."
  type      = string
  sensitive = true
}

variable "public_ip" {
  description = "Boolean to control public IP creation."
  type        = bool
  default     = false
}

variable "dns_label" {
  description = "Shortname for the public IP's FQDN."
  type        = string
  default     = null
}

variable "resource_prefix" {
  description = "Optional prefix for the VM resources."
  type        = string
  default     = ""
}

//=============================================================

/* Not yet implemented
variable "generate_rdp_files" {
  type    = bool
  default = false
}

Example file:
full address:s:arcwinvm-f7a1d2eb-win1.uksouth.cloudapp.azure.com:3389
prompt for credentials:i:1
administrative session:i:1
*/

//=============================================================
