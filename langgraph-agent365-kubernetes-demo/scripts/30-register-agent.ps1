<#
.SYNOPSIS
  Registers the agent identity in the Agent 365 registry so its telemetry is accepted and it shows up in the admin center.
.DESCRIPTION
  Without registration the Agent 365 exporter is rejected with HTTP 403.
  Uses the Agent Registration API (beta, so details can change). PowerShell 7 is recommended, plus the Microsoft.Graph.Authentication module:
      Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
  A device-code prompt asks you to sign in at https://microsoft.com/devicelogin in a browser.
#>
param(
    [string]$TenantId,
    [string]$AgentId,
    [string]$BlueprintAppId,
    [string]$DisplayName = "LangGraph Agent (Amazon EKS)",
    [string]$Platform = "Amazon EKS"
)
. "$PSScriptRoot\_common.ps1"
if (-not $TenantId) { $TenantId = $env:DEMO_TENANT_ID }
if (-not $AgentId) { $AgentId = $env:DEMO_AGENT_ID }
if (-not $BlueprintAppId) { $BlueprintAppId = $env:DEMO_BLUEPRINT_APP_ID }
Require "DEMO_TENANT_ID" $TenantId "Fill in scripts\config.ps1."
Require "DEMO_AGENT_ID" $AgentId "Fill in scripts\config.ps1."
Require "DEMO_BLUEPRINT_APP_ID" $BlueprintAppId "Fill in scripts\config.ps1."
if (-not (Get-Module -ListAvailable Microsoft.Graph.Authentication)) { throw "Run: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser" }

Connect-MgGraph -TenantId $TenantId -Scopes "AgentRegistration.ReadWrite.All", "User.Read" -UseDeviceCode -NoWelcome
$me = Get-MgContext | Select-Object -ExpandProperty Account
$user = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$me"
$owner = $user.id
$now = (Get-Date).ToUniversalTime().ToString("o")

$body = @{
    displayName = $DisplayName
    description = "LangGraph ReAct agent wrapped with the Agent 365 SDK. Authenticates with a federated Kubernetes service account token (no secret)."
    createdBy = $owner; ownerIds = @($owner)
    sourceAgentId = $AgentId; originatingStore = $Platform
    agentIdentityId = $AgentId; agentIdentityBlueprintId = $BlueprintAppId
    sourceCreatedDateTime = $now; sourceLastModifiedDateTime = $now
    agentCard = @{
        name = $DisplayName; version = "1.0.0"; description = "Directory lookup agent (LangGraph)"; provider = "Demo"
        capabilities = @{ streaming = $false; pushNotifications = $false }
        defaultInputModes = @("text"); defaultOutputModes = @("text")
        skills = @(@{ id = "find-employee"; name = "Find employee"; description = "Look up an employee in the directory" })
    }
} | ConvertTo-Json -Depth 8

try {
    $r = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/copilot/agentRegistrations" -ContentType application/json -Body $body
    Write-Host "Registered: $($r.id)" -ForegroundColor Green
} catch {
    Write-Host "Registration failed: $($_.Exception.Message) $($_.ErrorDetails.Message)" -ForegroundColor Red
    Write-Host "If it says the agent is already registered, that is fine."
}
