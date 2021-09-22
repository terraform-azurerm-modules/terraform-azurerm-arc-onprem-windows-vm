
## Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM

## Not required as VM resource is set provision_vm_agent = false

# Write-Host "Configure the OS to allow Azure Arc Agent to be deploy on an Azure VM"
# Set-Service WindowsAzureGuestAgent -StartupType Disabled -Verbose
# Stop-Service WindowsAzureGuestAgent -Force -Verbose

Write-Host "Configuring the internal OS firewall to block access to the Azure IMDS (169.254.169.254)."
New-NetFirewallRule -Name BlockAzureIMDS -DisplayName "Block access to Azure IMDS" -Enabled True -Profile Any -Direction Outbound -Action Block -RemoteAddress 169.254.169.254

# Add registry setting to allow WinRM with local administrator IDs
# <https://docs.microsoft.com/windows-server/manage/windows-admin-center/support/troubleshooting#i-can-connect-to-some-servers-but-not-others>
# REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1
New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name  'LocalAccountTokenFilterPolicy' -Value '1' -PropertyType 'DWORD' –Force