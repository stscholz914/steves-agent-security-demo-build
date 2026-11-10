<#
.SYNOPSIS
  Deletes the EKS demo cluster and everything billable around it, so the AWS side costs about $0 until you rebuild.
.DESCRIPTION
  Run this when you are finished with the demo. To use it again, run scripts\60-rebuild-eks.ps1 about an hour ahead.
  Deletes: the agent, the node group, the cluster, and the networking eksctl created (including the NAT gateway).
  Keeps: the Entra blueprint, agent identities and Azure side (the rebuild replaces the federated credential).
  Prerequisites: aws login --region <your region>, eksctl and aws on PATH.
.PARAMETER Force
  Skip the confirmation prompt.
.PARAMETER VerifyOnly
  Delete nothing; only report whether anything billable still exists in the region.
.PARAMETER UseCloudFormation
  Skip eksctl and delete the CloudFormation stacks directly (works behind TLS inspection).
#>
param(
    [string]$ClusterName,
    [string]$Region,
    [switch]$Force,
    [switch]$VerifyOnly,
    [switch]$UseCloudFormation
)
. "$PSScriptRoot\_common.ps1"
if (-not $ClusterName) { $ClusterName = if ($env:DEMO_CLUSTER_NAME) { $env:DEMO_CLUSTER_NAME } else { "a365-demo" } }
if (-not $Region) { $Region = if ($env:DEMO_AWS_REGION) { $env:DEMO_AWS_REGION } else { "us-east-2" } }

foreach ($t in 'aws', 'eksctl') {
    if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { throw "'$t' is not installed or not on PATH. Open a NEW terminal window, or run scripts\setup-device.ps1." }
}
$acct = Quiet { aws sts get-caller-identity --query Account --output text }
if (-not $acct) { throw "Not signed in to AWS. Run: aws login --region $Region" }

function Get-BillableResources {
    $found = [ordered]@{}
    $c = aws eks list-clusters --region $Region --query "clusters" --output text
    if ($c) { $found["EKS clusters"] = $c }
    $nat = aws ec2 describe-nat-gateways --region $Region --filter "Name=state,Values=available,pending" --query "NatGateways[].NatGatewayId" --output text
    if ($nat) { $found["NAT gateways"] = $nat }
    $inst = aws ec2 describe-instances --region $Region --filters "Name=instance-state-name,Values=pending,running,stopping,stopped" --query "Reservations[].Instances[].InstanceId" --output text
    if ($inst) { $found["EC2 instances"] = $inst }
    $vol = aws ec2 describe-volumes --region $Region --query "Volumes[].VolumeId" --output text
    if ($vol) { $found["EBS volumes"] = $vol }
    $eip = aws ec2 describe-addresses --region $Region --query "Addresses[].PublicIp" --output text
    if ($eip) { $found["Elastic IPs"] = $eip }
    $lb = Quiet { aws elbv2 describe-load-balancers --region $Region --query "LoadBalancers[].LoadBalancerName" --output text }
    if ($lb) { $found["Load balancers"] = $lb }
    $stk = aws cloudformation list-stacks --region $Region --query "StackSummaries[?StackStatus!='DELETE_COMPLETE'].StackName" --output text
    if ($stk) { $found["CloudFormation stacks"] = $stk }
    return $found
}

function Show-Billable {
    $f = Get-BillableResources
    if ($f.Count -eq 0) {
        Write-Host "Nothing billable found in $Region for account $acct. AWS cost is about `$0." -ForegroundColor Green
        return $true
    }
    Write-Host "These resources still exist in $Region (they may still cost money):" -ForegroundColor Yellow
    $f.GetEnumerator() | ForEach-Object { Write-Host ("  {0,-22} {1}" -f $_.Key, $_.Value) }
    return $false
}

if ($VerifyOnly) { Step "Checking for billable resources"; [void](Show-Billable); return }

# Deletes what eksctl built by removing its CloudFormation stacks: node groups first, then the cluster (and VPC, NAT gateway).
# Needs no connection to the cluster itself, so it works behind TLS inspection.
function Remove-ViaCloudFormation {
    $addons = Quiet { aws eks list-addons --cluster-name $ClusterName --region $Region --query "addons" --output text }
    foreach ($a in ($addons -split "\s+" | Where-Object { $_ })) {
        Write-Host "Removing add-on $a"
        Quiet { aws eks delete-addon --cluster-name $ClusterName --region $Region --addon-name $a --query "addon.status" --output text } | Out-Null
    }
    $names = (aws cloudformation list-stacks --region $Region --query "StackSummaries[?StackStatus!='DELETE_COMPLETE'].StackName" --output text) -split "\s+" | Where-Object { $_ }
    $ng = $names | Where-Object { $_ -like "eksctl-$ClusterName-nodegroup-*" }
    $cl = $names | Where-Object { $_ -eq "eksctl-$ClusterName-cluster" }
    foreach ($s in $ng) {
        Write-Host "Deleting node group stack $s (about 5-10 minutes)"
        aws cloudformation delete-stack --stack-name $s --region $Region
        aws cloudformation wait stack-delete-complete --stack-name $s --region $Region
    }
    foreach ($s in $cl) {
        Write-Host "Deleting cluster stack $s (about 10-15 minutes)"
        aws cloudformation delete-stack --stack-name $s --region $Region
        aws cloudformation wait stack-delete-complete --stack-name $s --region $Region
    }
}

Step "Delete cluster '$ClusterName' in $Region (AWS account $acct)"
$status = Quiet { aws eks describe-cluster --name $ClusterName --region $Region --query cluster.status --output text }
if (-not $status) {
    Write-Host "Cluster '$ClusterName' does not exist. Checking for leftovers."
} else {
    Write-Host "This permanently deletes the cluster, its node, the agent pod and the network. You can rebuild with scripts\60-rebuild-eks.ps1 (about 15-40 minutes)."
    if (-not $Force) {
        $a = Read-Host "Type DELETE to continue"
        if ($a -ne "DELETE") { Write-Host "Cancelled."; return }
    }
    $ok = $false
    # This account turns on CloudFormation termination protection for these stacks; it must be off before they can be deleted.
    $protNames = (aws cloudformation list-stacks --region $Region --query "StackSummaries[?StackStatus!='DELETE_COMPLETE'].StackName" --output text) -split "\s+" | Where-Object { $_ -like "eksctl-$ClusterName-*" }
    foreach ($p in $protNames) { Quiet { aws cloudformation update-termination-protection --stack-name $p --region $Region --no-enable-termination-protection } | Out-Null }
    if (-not $UseCloudFormation) {
        eksctl delete cluster --name $ClusterName --region $Region --wait --disable-nodegroup-eviction 2>&1 | ForEach-Object { "$_" }
        $ok = ($LASTEXITCODE -eq 0)
        if (-not $ok) { Write-Host "eksctl could not finish (often TLS inspection blocking the cluster endpoint). Falling back to deleting the CloudFormation stacks directly." -ForegroundColor Yellow }
    }
    if (-not $ok) { Remove-ViaCloudFormation }
}

Step "Verify nothing billable is left"
$clean = Show-Billable
if (-not $clean) {
    Write-Host "`nIf anything above remains after a few minutes, re-run this script. For stray items, delete them in the AWS console for $Region." -ForegroundColor Yellow
    exit 1
}
Write-Host "`nTo run the demo again, start the rebuild about an hour ahead:  .\scripts\60-rebuild-eks.ps1" -ForegroundColor Green
