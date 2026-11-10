# Creates the Copilot DLP policy and its rules. Run 00-connect.ps1 first.
#
#   Rule 1  Block Copilot from labelled content     (label condition,  action: exclude content from processing)
#   Rule 2  Block sensitive prompts                 (SIT condition,    action: block processing prompts)
#   Rule 3  Block web search on sensitive prompts   (SIT condition,    action: block web searches) - created in the portal, see README Part 4
#
# The policy starts in TestWithoutNotifications. Switch it on with 50-enable-policy.ps1.
param(
    [string]$PolicyName = "",
    [ValidateSet("TestWithoutNotifications", "TestWithNotifications", "Enable")]
    [string]$Mode = "TestWithoutNotifications"
)
. "$PSScriptRoot\config.ps1"
if (-not $PolicyName) { $PolicyName = $DEMO_DLP_POLICY }

# Scope: the Microsoft 365 Copilot location, limited to the demo users.
$inclusions = $DEMO_USER_OBJECT_IDS | ForEach-Object { @{ Type = "IndividualResource"; Identity = $_ } }
$locations  = ConvertTo-Json -Compress -Depth 6 @(@{ Workload = "Applications"; Location = "Copilot.M365"; Inclusions = @($inclusions) })

if (-not (Get-DlpCompliancePolicy -Identity $PolicyName -ErrorAction SilentlyContinue)) {
    New-DlpCompliancePolicy -Name $PolicyName -Mode $Mode -Locations $locations `
        -EnforcementPlanes @("CopilotExperiences") `
        -Comment "Protects Microsoft 365 Copilot interactions for the demo users." | Out-Null
    Write-Host "Created policy '$PolicyName' in mode $Mode" -ForegroundColor Green
} else { Write-Host "Policy '$PolicyName' already exists" }

function New-AdvancedRule($subCondition) {
    ConvertTo-Json -Depth 12 @{ Version = "1.0"; Condition = @{ Operator = "And"; SubConditions = @($subCondition) } }
}

# Rule 1: labels. Look the label GUIDs up in your own tenant, they are different in every tenant.
$labelNames = "AID-HC-CustomerPII", "AID-HC-MnA-MNPI", "AID-Conf-HR"
$labelRefs  = $labelNames | ForEach-Object { @{ type = "Sensitivity"; name = (Get-Label -Identity $_).Guid.ToString() } }
$rule1 = New-AdvancedRule @{
    ConditionName = "ContentContainsSensitiveInformation"
    Value = @(@{ groups = @(@{ Operator = "Or"; name = "Default"; labels = @($labelRefs) }) })
}
New-DlpComplianceRule -Name "Block Copilot from labelled content (Customer PII, M&A, HR)" -Policy $PolicyName `
    -AdvancedRule $rule1 -RestrictAccess @(@{ setting = "ExcludeContentProcessing"; value = "Block" }) | Out-Null
Write-Host "Created rule 1" -ForegroundColor Green

# Rule 2: sensitive information types typed into a prompt.
function New-SitRef($id, $name) { @{ id = $id; name = $name; classifiertype = "Content"; mincount = "1"; minconfidence = "85"; maxconfidence = "100" } }
$rule2 = New-AdvancedRule @{
    ConditionName = "ContentContainsSensitiveInformation"
    Value = @(@{ groups = @(@{ Operator = "Or"; name = "Default"; sensitivetypes = @(
        (New-SitRef "a44669fe-0d48-453d-a9b1-2cc83f2cba77" "U.S. Social Security Number (SSN)"),
        (New-SitRef "50842eb7-edc8-4019-85dd-5a5c1f2bb085" "Credit Card Number")) }) })
}
New-DlpComplianceRule -Name "Block sensitive prompts (SSN, credit card)" -Policy $PolicyName `
    -AdvancedRule $rule2 -RestrictAccess @(@{ setting = "UploadText"; value = "Block" }) | Out-Null
Write-Host "Created rule 2" -ForegroundColor Green

Write-Host "`nRule 3 (block web search) is created in the Purview portal. See README Part 4." -ForegroundColor Yellow
Get-DlpComplianceRule -Policy $PolicyName | Select-Object Name, Mode, Disabled | Format-Table -AutoSize
