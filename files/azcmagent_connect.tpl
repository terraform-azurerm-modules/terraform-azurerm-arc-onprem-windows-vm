
## Create the C:\terraform directory if not present

New-Item -Path "C:\Terraform" -ItemType "directory" -Force
Set-Location -Path "C:\Terraform"

"$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
 --service-principal-id ${service_principal_appid} `
 --service-principal-secret ${service_principal_secret} `
 --resource-group ${resource_group_name} `
 --tenant-id ${tenant_id} `
 --location ${location} `
 --subscription-id ${subscription_id} `
 --tags "${tags}"
