terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.51.0"
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

  arc = local.azcmagent_connect ? merge(var.arc, {tags = local.arc_tags_string}) : null

  // Create the custom data file

  custom_data_base = file("${path.module}/files/winrm_http_imds.ps1")

  custom_data_install = local.azcmagent_download ? file("${path.module}/files/azcmagent_install.ps1") : "Write-Host \"Skipping azcmagent installation.\""

  custom_data_connect = local.azcmagent_connect ? templatefile("${path.module}/files/azcmagent_connect.tpl", local.arc) : "Write-Host \"Skipping Azure Arc connect step.\""

  custom_data = join("\n", "Start-Transcript -Path C:\\\\Terraform\\custom_data.log", local.custom_data_base, local.custom_data_install, local.custom_data_connect, "Stop-Transcript")

  // Append the

}

resource "azurerm_public_ip" "arc" {
  name                = "${var.name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  allocation_method = "Static"
  domain_name_label = var.dns_label
}

resource "azurerm_network_interface" "arc" {
  name                = "${var.name}-nic"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.arc.id
  }
}

resource "azurerm_network_interface_application_security_group_association" "arc" {
  network_interface_id          = azurerm_network_interface.arc.id
  application_security_group_id = var.asg_id
}

resource "azurerm_windows_virtual_machine" "arc" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  admin_username = var.admin_username
  admin_password = var.admin_password
  size           = var.size

  network_interface_ids = [azurerm_network_interface.arc.id]

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

  # Don't provision the Azure Agent - needs to be missing for Azure Arc agent installation
  provision_vm_agent         = false
  allow_extension_operations = false

  # Upload winrm PowerShell script via the custom data - enables winrm and blocks IMDS
  custom_data = base64encode(local.custom_data)

  # Set up winrm listener on http, or port 5985.
  # Can also add an https listener on port 5986, but needs a cert in Azure Key Vault.
  winrm_listener {
    protocol = "Http"
  }

  # Autologon configuration needed for WinRM
  additional_unattend_content {
    setting = "AutoLogon"
    content = "<AutoLogon><Password><Value>${var.admin_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.admin_username}</Username></AutoLogon>"
  }

  # Create C:\Terraform, copies custom data  PowerShell script into there and executes it to configure WinRM
  additional_unattend_content {
    setting = "FirstLogonCommands"
    content = file("${path.module}/files/FirstLogonCommands.xml")
  }

  connection {
    type     = "winrm"
    port     = "5985"
    host     = azurerm_public_ip.arc.ip_address
    user     = var.admin_username
    password = var.admin_password
    https    = false
    insecure = true
    timeout  = "2m"
  }

  provisioner "remote-exec" {
    on_failure = continue
    inline = [
      "PowerShell.exe -ExecutionPolicy Bypass Write-Host \"Inline PowerShell command\"",
    ]
  }

  provisioner "file" {
    source      = "${path.module}/files/test.ps1"
    destination = "C:/Terraform/test.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "PowerShell.exe -ExecutionPolicy Bypass C:\\\\Terraform\\test.ps1",
    ]
  }
}
