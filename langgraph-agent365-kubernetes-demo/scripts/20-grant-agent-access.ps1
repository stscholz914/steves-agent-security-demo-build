<#
.SYNOPSIS
  Gives the agent identity the two permissions the demo agent needs (least privilege), then adds the federated trust.
.DESCRIPTION
  1. Microsoft Graph application permission User.Read.All  (lets the agent look people up in the directory).
  2. Azure role "Cognitive Services OpenAI User" on the Azure OpenAI account only (lets it call the model).
  Deliberately NOT granted: any group permission. The demo shows that request being refused.
  Prerequisites: az login to the tenant; Privileged Role Administrator (or Global Administrator) for step 1,
  Owner / User Access Administrator on the OpenAI resource group for step 2.
  Safe to re-run: "already exists" messages are normal.
#>
param(
    [string]$AgentId,
    [string]$OpenAIResourceGroup,
    [string]$OpenAIAccount
)
. "$PSScriptRoot\_common.ps1"
if (-not $AgentId) { $AgentId = $env:DEMO_AGENT_ID }
if (-not $OpenAIResourceGroup) { $OpenAIResourceGroup = $env:DEMO_OPENAI_RESOURCE_GROUP }
if (-not $OpenAIAccount) { $OpenAIAccount = $env:DEMO_OPENAI_ACCOUNT }
Require "DEMO_AGENT_ID" $AgentId "Copy the agent identity's Object ID from the Entra admin center into scripts\config.ps1."
Require "DEMO_OPENAI_ACCOUNT" $OpenAIAccount "Run scripts\10-create-azure-openai.ps1 first and copy its output into scripts\config.ps1."

Step "1. Microsoft Graph permission: User.Read.All"
$graphSp = az rest --method GET --uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'&`$select=id" --query "value[0].id" -o tsv
Check "find the Microsoft Graph service principal"
$userReadAll = "df021288-bdef-4463-88db-98f22de89214"
$body = @{ principalId = $AgentId; resourceId = $graphSp; appRoleId = $userReadAll } | ConvertTo-Json -Compress
$tmp = Join-Path $env:TEMP "grant-$([guid]::NewGuid().ToString('N')).json"
Set-Content -Path $tmp -Value $body -NoNewline
try {
    $out = az rest --method POST --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$graphSp/appRoleAssignedTo" --headers "Content-Type=application/json" --body "@$tmp" --query id -o tsv 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Host "Granted." }
    elseif ("$out" -match "already exists") { Write-Host "Already granted." }
    else { throw "Could not grant User.Read.All: $out" }
} finally { Remove-Item $tmp -ErrorAction SilentlyContinue }

Step "2. Azure role: Cognitive Services OpenAI User on $OpenAIAccount"
$scope = az cognitiveservices account show -g $OpenAIResourceGroup -n $OpenAIAccount --query id -o tsv
Check "find the Azure OpenAI account"
$existing = az role assignment list --assignee $AgentId --scope $scope --query "[?roleDefinitionName=='Cognitive Services OpenAI User'] | length(@)" -o tsv
if ($existing -and [int]$existing -gt 0) { Write-Host "Already assigned." }
else {
    az role assignment create --assignee-object-id $AgentId --assignee-principal-type ServicePrincipal --role "Cognitive Services OpenAI User" --scope $scope --query id -o tsv
    Check "assign the OpenAI role"
}
Write-Host "`nDone. Role assignments can take a few minutes to take effect." -ForegroundColor Green
