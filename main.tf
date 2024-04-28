terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.51.0"
    }
  }
}

locals {
  # prefix the resource names is the variable has been specified
  name = try(length(var.resource_prefix), 0) > 0 ? "${var.resource_prefix}-${var.name}" : var.name

  # Set a boolean for the connect if the arc object has been set
  azcmagent_connect = var.arc == null ? false : true

  // And then force azcmagent_download to true
  azcmagent_download = local.azcmagent_connect ? true : var.azcmagent

  // If connecting then convert map of tags to string of comma delimited key=value pairs and merge into the arc object.

  arc_tags_string = local.azcmagent_connect && try(length(var.arc.tags), 0) > 0 ? (
    join(",", [for key, value in var.arc.tags :
    "${key}=${value}"])
    ) : (
    null
  )

  arc = local.azcmagent_connect ? merge(var.arc, { tags = local.arc_tags_string }) : null

  // Create the custom data file
  // The FirstLogonCommands will copy custom_data multiline string to C:\AzureData\CustomData.bin C:\Terraform\custom_data.ps1 then runs it
  // Transcript should go into C:\Terraform\custom_data.log

  custom_data = join("\n", [
    "Start-Transcript -Path C:\\Terraform\\custom_data.log",
    file("${path.module}/files/azure_agent_imds.ps1"),
    local.azcmagent_download ? file("${path.module}/files/azcmagent_install.ps1") : "Write-Host \"Skipping azcmagent installation.\"",
    local.azcmagent_connect ? templatefile("${path.module}/files/azcmagent_connect.tpl", local.arc) : "Write-Host \"Skipping Azure Arc connect step.\"",
    "Stop-Transcript"
  ])
}

resource "azurerm_public_ip" "onprem" {
  for_each            = toset(var.public_ip ? ["pip"] : [])
  name                = "${var.name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  allocation_method = "Static"
  domain_name_label = var.dns_label
}

resource "azurerm_network_interface" "onprem" {
  name                = "${var.name}-nic"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip ? azurerm_public_ip.onprem["pip"].id : null
  }
}

resource "azurerm_network_interface_application_security_group_association" "onprem" {
  network_interface_id          = azurerm_network_interface.onprem.id
  application_security_group_id = var.asg_id
}

resource "azurerm_windows_virtual_machine" "onprem" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  admin_username = var.admin_username
  admin_password = var.admin_password
  size           = var.size

  network_interface_ids = [azurerm_network_interface.onprem.id]

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.name}-os"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  // Pointless, but impossible to not have an identity
  identity {
    type = "SystemAssigned"
  }

  # Don't provision the Azure Agent - needs to be missing for Azure Arc agent installation
  provision_vm_agent         = false
  allow_extension_operations = false

  # Upload winrm PowerShell script via the custom data
  custom_data = base64encode(local.custom_data)

  # Autologon configuration to kic off those FirstLogon
  additional_unattend_content {
    setting = "AutoLogon"
    content = "<AutoLogon><Password><Value>${var.admin_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.admin_username}</Username></AutoLogon>"
  }

  # Create C:\Terraform, copies custom data  PowerShell script into there and executes it to configure WinRM
  additional_unattend_content {
    setting = "FirstLogonCommands"
    content = file("${path.module}/files/FirstLogonCommands.xml")
  }
}
