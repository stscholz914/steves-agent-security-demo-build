<#
.SYNOPSIS
  Builds (or rebuilds) the Amazon EKS cluster and deploys the LangGraph agent. Safe to re-run: finished steps are skipped.
.DESCRIPTION
  1. Creates the EKS cluster, 2. installs the network add-ons, 3. adds one worker computer (node),
  4. connects kubectl, 5. tells Microsoft Entra to trust this cluster's tokens (federated credential),
  6. deploys the agent, 7. runs a smoke test.
  Prerequisites: scripts\config.ps1 filled in; signed in with:  aws login --region <region>   and   az login --tenant <tenant>
  Takes 25-40 minutes. Costs about $0.26/hour while the cluster exists (see 62-delete-eks.ps1 to stop the meter).
  Lessons built in:
   - Some AWS accounts only allow certain regions; set DEMO_AWS_REGION accordingly.
   - Free Tier AWS accounts reject some instance types; m7i-flex.large is accepted.
   - No IAM OIDC provider is created (some policies block it, and Entra does not need it).
   - A new cluster has a new issuer URL, so the Entra federated credential is replaced each rebuild.
#>
param(
    [string]$ClusterName, [string]$Region, [string]$NodeType,
    [string]$TenantId, [string]$BlueprintAppId, [string]$BlueprintObjectId, [string]$AgentId,
    [string]$OpenAIEndpoint, [string]$OpenAIDeployment,
    [string]$FicName = "eks-langgraph-sa"
)
. "$PSScriptRoot\_common.ps1"
if (-not $ClusterName) { $ClusterName = if ($env:DEMO_CLUSTER_NAME) { $env:DEMO_CLUSTER_NAME } else { "a365-demo" } }
if (-not $Region) { $Region = if ($env:DEMO_AWS_REGION) { $env:DEMO_AWS_REGION } else { "us-east-2" } }
if (-not $NodeType) { $NodeType = if ($env:DEMO_NODE_TYPE) { $env:DEMO_NODE_TYPE } else { "m7i-flex.large" } }
if (-not $TenantId) { $TenantId = $env:DEMO_TENANT_ID }
if (-not $BlueprintAppId) { $BlueprintAppId = $env:DEMO_BLUEPRINT_APP_ID }
if (-not $BlueprintObjectId) { $BlueprintObjectId = $env:DEMO_BLUEPRINT_OBJECT_ID }
if (-not $AgentId) { $AgentId = $env:DEMO_AGENT_ID }
if (-not $OpenAIEndpoint) { $OpenAIEndpoint = $env:DEMO_OPENAI_ENDPOINT }
if (-not $OpenAIDeployment) { $OpenAIDeployment = if ($env:DEMO_OPENAI_DEPLOYMENT) { $env:DEMO_OPENAI_DEPLOYMENT } else { "gpt-4.1-mini" } }
$fill = "Copy scripts\config.example.ps1 to scripts\config.ps1 and fill it in."
Require "DEMO_TENANT_ID" $TenantId $fill
Require "DEMO_BLUEPRINT_APP_ID" $BlueprintAppId $fill
Require "DEMO_BLUEPRINT_OBJECT_ID" $BlueprintObjectId $fill
Require "DEMO_AGENT_ID" $AgentId $fill
Require "DEMO_OPENAI_ENDPOINT" $OpenAIEndpoint $fill

$root = Split-Path $PSScriptRoot -Parent
$ns = "a365-agents"

Step "0. Prerequisites"
foreach ($t in 'aws', 'eksctl', 'kubectl', 'az') {
    if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { throw "'$t' is not installed or not on PATH. Open a NEW terminal window, or run scripts\setup-device.ps1 as administrator." }
}
$acct = Quiet { aws sts get-caller-identity --query Account --output text }
if (-not $acct) { throw "Not signed in to AWS. Run: aws login --region $Region" }
Write-Host "AWS account: $acct   Region: $Region"
$tid = Quiet { az account show --query tenantId -o tsv }
if ($tid -ne $TenantId) { throw "Azure CLI is not signed in to tenant $TenantId. Run: az login --tenant $TenantId" }
Write-Host "Azure tenant: $tid"

Step "1. EKS control plane (about 10-15 minutes)"
$status = Quiet { aws eks describe-cluster --name $ClusterName --region $Region --query cluster.status --output text }
if ($status -eq "ACTIVE") {
    Write-Host "Cluster $ClusterName already exists (ACTIVE), skipping."
} else {
    Show (eksctl create cluster --name $ClusterName --region $Region --without-nodegroup 2>&1)
    # eksctl can stop at its IAM OIDC step in locked-down accounts. If the control plane exists, carry on.
    $status = Quiet { aws eks describe-cluster --name $ClusterName --region $Region --query cluster.status --output text }
    if ($status -ne "ACTIVE") { throw "Cluster was not created. Check CloudFormation in the AWS console for region $Region." }
}

Step "2. Core add-ons (network, proxy, DNS)"
$have = (aws eks list-addons --cluster-name $ClusterName --region $Region --query "addons" --output text) -split "\s+"
foreach ($a in 'vpc-cni', 'kube-proxy', 'coredns') {
    if ($have -contains $a) { Write-Host "$a already installed" }
    else { aws eks create-addon --cluster-name $ClusterName --region $Region --addon-name $a --query "addon.addonName" --output text; Check "create-addon $a" }
}

Step "3. Worker node ($NodeType) (about 5-10 minutes)"
$ngs = aws eks list-nodegroups --cluster-name $ClusterName --region $Region --query nodegroups --output text
if ($ngs) {
    Write-Host "Node group exists: $ngs"
} else {
    Show (eksctl create nodegroup --cluster $ClusterName --region $Region --name ng1 --nodes 1 --node-type $NodeType 2>&1)
    Check "create nodegroup"
}

Step "4. Connect kubectl"
aws eks update-kubeconfig --name $ClusterName --region $Region
Check "update-kubeconfig"
& (Join-Path $PSScriptRoot "fix-kubeconfig-tls.ps1")
for ($i = 0; $i -lt 30; $i++) {
    if ((Quiet { kubectl get nodes --no-headers }) -match " Ready") { break }
    Start-Sleep 10
}
kubectl get nodes

Step "5. Entra trust: federated credential for this cluster's issuer"
$issuer = aws eks describe-cluster --name $ClusterName --region $Region --query cluster.identity.oidc.issuer --output text
Write-Host "Issuer: $issuer"
$base = "https://graph.microsoft.com/v1.0/applications/$BlueprintObjectId/federatedIdentityCredentials"
$existing = (az rest --method GET --uri $base -o json | ConvertFrom-Json).value | Where-Object { $_.name -eq $FicName }
if ($existing -and $existing.issuer -eq $issuer) {
    Write-Host "Federated credential already matches this cluster."
} else {
    if ($existing) {
        Write-Host "Replacing old credential (issuer $($existing.issuer))"
        az rest --method DELETE --uri "$base/$($existing.id)" | Out-Null; Check "delete old credential"
    }
    $body = @{ name = $FicName; issuer = $issuer; subject = "system:serviceaccount:${ns}:langgraph-agent"; audiences = @("api://AzureADTokenExchange") } | ConvertTo-Json -Compress
    $tmp = Join-Path $env:TEMP "fic-$([guid]::NewGuid().ToString('N')).json"
    Set-Content -Path $tmp -Value $body -NoNewline
    try { az rest --method POST --uri $base --headers "Content-Type=application/json" --body "@$tmp" --query id -o tsv; Check "create credential" }
    finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
}

Step "6. Deploy the agent"
$yaml = (Get-Content (Join-Path $root "k8s\agent.yaml") -Raw).
    Replace('__TENANT_ID__', $TenantId).Replace('__BLUEPRINT_ID__', $BlueprintAppId).Replace('__AGENT_ID__', $AgentId).
    Replace('__OPENAI_ENDPOINT__', $OpenAIEndpoint).Replace('__OPENAI_DEPLOYMENT__', $OpenAIDeployment).Replace('__ENV__', 'Amazon EKS')
$yaml | kubectl apply -f -
Check "apply manifest"
kubectl -n $ns create configmap langgraph-agent-code --from-file="$root\agent\app.py" --from-file="$root\agent\identity.py" --dry-run=client -o yaml | kubectl apply -f -
Check "apply code configmap"
kubectl -n $ns rollout restart deploy/langgraph-agent | Out-Null
kubectl -n $ns rollout status deploy/langgraph-agent --timeout=600s
Check "rollout"

Step "7. Smoke test"
Start-Sleep 5
kubectl -n $ns get pods
kubectl -n $ns exec deploy/langgraph-agent -c agent -- python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8080/identity').read().decode())"
Write-Host "`nDone. Load the helpers with:  . .\scripts\demo-helpers.ps1   then run: Test-DemoReady" -ForegroundColor Green
Write-Host "Cost reminder: about `$0.26/hour. To delete everything: .\scripts\62-delete-eks.ps1" -ForegroundColor Yellow
