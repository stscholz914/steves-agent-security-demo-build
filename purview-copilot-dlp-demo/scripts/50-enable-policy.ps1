# Switches the Copilot DLP policy on (Enable), or back to test mode. Run 00-connect.ps1 first.
param([ValidateSet("Enable", "TestWithoutNotifications", "TestWithNotifications", "Disable")][string]$Mode = "Enable")
. "$PSScriptRoot\config.ps1"

Set-DlpCompliancePolicy -Identity $DEMO_DLP_POLICY -Mode $Mode
Get-DlpCompliancePolicy -Identity $DEMO_DLP_POLICY | Select-Object Name, Mode, DistributionStatus | Format-List
Get-DlpComplianceRule -Policy $DEMO_DLP_POLICY | Select-Object Name, Disabled, Mode | Format-Table -AutoSize
Write-Host "Policy changes can take up to about an hour to reach Copilot." -ForegroundColor Yellow
