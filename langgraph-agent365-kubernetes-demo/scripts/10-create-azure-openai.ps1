<#
.SYNOPSIS
  Creates the Azure OpenAI account and model deployment the agent will call, with API keys switched OFF.
.DESCRIPTION
  After this runs, the only way to call the model is with a Microsoft Entra identity (the agent's), never a key.
  Prerequisites: Azure CLI signed in (az login) to the subscription you want to use; Contributor or Owner on it.
  Safe to re-run. Takes about 2 minutes.
.PARAMETER AccountName
  Globally unique, 3-24 lowercase letters/digits. Becomes https://<AccountName>.openai.azure.com/
#>
param(
    [Parameter(Mandatory)][ValidateLength(3, 24)][string]$AccountName,
    [string]$ResourceGroup = "rg-a365-langgraph",
    [string]$Location = "eastus2",
    [string]$Deployment = "gpt-4.1-mini",
    [string]$ModelVersion = "2025-04-14",
    [int]$Capacity = 50
)
. "$PSScriptRoot\_common.ps1"

Step "Subscription"
$sub = Quiet { az account show --query "[name,id]" -o tsv }
if (-not $sub) { throw "Not signed in to Azure. Run: az login" }
Write-Host ($sub -join " | ")

Step "Resource group $ResourceGroup ($Location)"
az group create --name $ResourceGroup --location $Location --query "properties.provisioningState" -o tsv
Check "create resource group"

Step "Azure OpenAI account $AccountName"
$exists = Quiet { az cognitiveservices account show -g $ResourceGroup -n $AccountName --query name -o tsv }
if ($exists) { Write-Host "already exists" }
else {
    az cognitiveservices account create --name $AccountName --resource-group $ResourceGroup --location $Location --kind OpenAI --sku S0 --custom-domain $AccountName --yes --query "properties.provisioningState" -o tsv
    Check "create account (the name may already be taken; try another)"
}

Step "Model deployment $Deployment"
$dep = Quiet { az cognitiveservices account deployment show -g $ResourceGroup -n $AccountName --deployment-name $Deployment --query name -o tsv }
if ($dep) { Write-Host "already exists" }
else {
    az cognitiveservices account deployment create -g $ResourceGroup -n $AccountName --deployment-name $Deployment --model-name $Deployment --model-version $ModelVersion --model-format OpenAI --sku-name GlobalStandard --sku-capacity $Capacity --query "properties.provisioningState" -o tsv
    Check "create deployment (if quota is exceeded, lower -Capacity or try another -Location)"
}

Step "Turn off API keys (Entra identity only)"
$id = az cognitiveservices account show -g $ResourceGroup -n $AccountName --query id -o tsv
az resource update --ids $id --set properties.disableLocalAuth=true --query "properties.disableLocalAuth" -o tsv
Check "disable local auth"

$endpoint = az cognitiveservices account show -g $ResourceGroup -n $AccountName --query properties.endpoint -o tsv
Write-Host "`nDone. Put these in scripts\config.ps1:" -ForegroundColor Green
Write-Host "  `$env:DEMO_OPENAI_RESOURCE_GROUP = `"$ResourceGroup`""
Write-Host "  `$env:DEMO_OPENAI_ACCOUNT        = `"$AccountName`""
Write-Host "  `$env:DEMO_OPENAI_ENDPOINT       = `"$endpoint`""
Write-Host "  `$env:DEMO_OPENAI_DEPLOYMENT     = `"$Deployment`""
