# Creates the five demo sensitivity labels and publishes them to the demo users.
#   Highly Confidential > Customer PII
#   Highly Confidential > Mergers and Acquisitions (MNPI)
#   Confidential        > Finance
#   Confidential        > HR
# "Public" and "General" already exist in the tenant's default label set.
# Run 00-connect.ps1 first.
. "$PSScriptRoot\config.ps1"

function Get-ParentLabel($displayName) {
    # The tenant's default parent labels have no ParentId of their own.
    $p = Get-Label | Where-Object { $_.DisplayName -eq $displayName -and -not $_.ParentId } | Select-Object -First 1
    if (-not $p) { throw "Parent label '$displayName' not found. Create it first in the Purview portal." }
    $p
}

$hc   = Get-ParentLabel "Highly Confidential"
$conf = Get-ParentLabel "Confidential"

$new = @(
    @{ Name = "AID-HC-CustomerPII"; Display = "Customer PII";                     Parent = $hc;   Tip = "Customer personal data. Not for AI processing." },
    @{ Name = "AID-HC-MnA-MNPI";    Display = "Mergers and Acquisitions (MNPI)"; Parent = $hc;   Tip = "Material non-public information about deals." },
    @{ Name = "AID-Conf-Finance";   Display = "Finance";                         Parent = $conf; Tip = "Unreleased financial results." },
    @{ Name = "AID-Conf-HR";        Display = "HR";                              Parent = $conf; Tip = "Compensation and employee data." }
)

foreach ($l in $new) {
    if (Get-Label -Identity $l.Name -ErrorAction SilentlyContinue) { Write-Host "Exists: $($l.Name)"; continue }
    New-Label -Name $l.Name -DisplayName $l.Display -Tooltip $l.Tip -ParentId $l.Parent.Guid -ContentType "File, Email" | Out-Null
    Write-Host "Created: $($l.Display)" -ForegroundColor Green
}

# Publish to the demo users. The parent labels must be in the policy as well as the sublabels.
$labels = @("AID-Conf-Finance", "AID-Conf-HR", "AID-HC-CustomerPII", "AID-HC-MnA-MNPI", $hc.Name, $conf.Name)
if (-not (Get-LabelPolicy -Identity $DEMO_LABEL_POLICY -ErrorAction SilentlyContinue)) {
    New-LabelPolicy -Name $DEMO_LABEL_POLICY -Labels $labels -ExchangeLocation $DEMO_USER_UPNS | Out-Null
    Write-Host "Created label policy '$DEMO_LABEL_POLICY'" -ForegroundColor Green
} else {
    Set-LabelPolicy -Identity $DEMO_LABEL_POLICY -AddLabels $labels
    Write-Host "Updated label policy '$DEMO_LABEL_POLICY'"
}

Write-Host "`nLabels can take up to 24 hours to reach every app. Files stamped by data\stamp.py do not need to wait." -ForegroundColor Yellow
