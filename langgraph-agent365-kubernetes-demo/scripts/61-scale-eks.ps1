<#
.SYNOPSIS
  Pause or resume the EKS worker node to save money without deleting the cluster.
.EXAMPLE
  .\scripts\61-scale-eks.ps1 -Nodes 0     # pause: stops node and disk charges (about $77/month saved)
  .\scripts\61-scale-eks.ps1 -Nodes 1     # resume: ready in about 5 minutes, agent restarts by itself
#>
param(
    [Parameter(Mandatory)][ValidateSet(0, 1)][int]$Nodes,
    [string]$ClusterName,
    [string]$Region
)
. "$PSScriptRoot\_common.ps1"
if (-not $ClusterName) { $ClusterName = if ($env:DEMO_CLUSTER_NAME) { $env:DEMO_CLUSTER_NAME } else { "a365-demo" } }
if (-not $Region) { $Region = if ($env:DEMO_AWS_REGION) { $env:DEMO_AWS_REGION } else { "us-east-2" } }
$ng = aws eks list-nodegroups --cluster-name $ClusterName --region $Region --query "nodegroups[0]" --output text
if (-not $ng -or $ng -eq "None") { throw "No node group found. Run scripts\60-rebuild-eks.ps1." }
Write-Host "Scaling node group $ng to $Nodes ..."
aws eks update-nodegroup-config --cluster-name $ClusterName --region $Region --nodegroup-name $ng --scaling-config "minSize=0,maxSize=1,desiredSize=$Nodes" --query "update.status" --output text
if ($Nodes -eq 1) {
    aws eks wait nodegroup-active --cluster-name $ClusterName --region $Region --nodegroup-name $ng
    aws eks update-kubeconfig --name $ClusterName --region $Region | Out-Null
    & (Join-Path $PSScriptRoot "fix-kubeconfig-tls.ps1")
    for ($i = 0; $i -lt 40; $i++) { if ((Quiet { kubectl get nodes --no-headers }) -match " Ready") { break }; Start-Sleep 10 }
    kubectl -n a365-agents rollout status deploy/langgraph-agent --timeout=600s
    kubectl -n a365-agents get pods
} else {
    Write-Host "Node is shutting down. The control plane (about `$73/month) still bills until you delete the cluster."
}
