# Connects to Security & Compliance PowerShell (Purview) as a lab admin.
# Run this first in every new PowerShell window. Dot-source it:  . .\00-connect.ps1
. "$PSScriptRoot\config.ps1"

if (-not (Get-Module -ListAvailable ExchangeOnlineManagement)) {
    Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force
}
Import-Module ExchangeOnlineManagement

# Interactive sign-in. Use -Device if your browser keeps picking the wrong account:
#   Connect-IPPSSession -Device -Organization $DEMO_TENANT_DOMAIN
Connect-IPPSSession -Organization $DEMO_TENANT_DOMAIN -ShowBanner:$false

Write-Host "Connected. Quick check:" -ForegroundColor Green
Get-DlpCompliancePolicy | Select-Object Name, Mode | Format-Table -AutoSize
