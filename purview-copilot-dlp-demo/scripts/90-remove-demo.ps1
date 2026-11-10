# Removes the DLP policy and the label policy created by this demo. Run 00-connect.ps1 first.
# The labels themselves are left in place (deleting a published label is slow and rarely needed).
param([switch]$Confirm)
. "$PSScriptRoot\config.ps1"
if (-not $Confirm) { Write-Host "Dry run. Would remove DLP policy '$DEMO_DLP_POLICY' and label policy '$DEMO_LABEL_POLICY'. Re-run with -Confirm."; return }

Get-DlpComplianceRule -Policy $DEMO_DLP_POLICY -ErrorAction SilentlyContinue | ForEach-Object { Remove-DlpComplianceRule -Identity $_.Identity -Confirm:$false }
Remove-DlpCompliancePolicy -Identity $DEMO_DLP_POLICY -Confirm:$false -ErrorAction SilentlyContinue
Remove-LabelPolicy -Identity $DEMO_LABEL_POLICY -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Removed." -ForegroundColor Green
