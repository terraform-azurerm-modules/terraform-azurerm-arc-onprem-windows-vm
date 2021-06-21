
## Create the C:\terraform directory if not present

New-Item -Path "C:\Terraform" -ItemType "directory" -Force
Set-Location -Path "C:\Terraform"

## Azure Arc agent Installation

Write-Host "Downloading azcmagent at $(Get-Date -UFormat '%H:%M:%S')"
$ProgressPreference="SilentlyContinue"
Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile AzureConnectedMachineAgent.msi
Write-Host "Download complete at $(Get-Date -UFormat '%H:%M:%S')"

# Install the package
Write-Host "Installing azcmagent at $(Get-Date -UFormat '%H:%M:%S')"
msiexec /i AzureConnectedMachineAgent.msi /l*v installationlog.txt /qn | Out-String
Write-Host "Install complete at $(Get-Date -UFormat '%H:%M:%S')"
