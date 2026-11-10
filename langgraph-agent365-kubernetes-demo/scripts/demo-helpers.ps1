# Demo helpers for the EKS leg. Load once per PowerShell window:  . .\scripts\demo-helpers.ps1
# Each function is one demo step, so you never have to type a long command live.

$script:NS = "a365-agents"

function Show-Cluster {
    Write-Host "=== Cluster nodes" -ForegroundColor Cyan
    kubectl get nodes
    Write-Host "`n=== Agent pod" -ForegroundColor Cyan
    kubectl -n $script:NS get pods
}

function Show-NoSecrets {
    Write-Host "=== Kubernetes Secrets in the agent namespace" -ForegroundColor Cyan
    kubectl -n $script:NS get secrets 2>&1 | ForEach-Object { "$_" }
    Write-Host "`n=== Container environment variables that look like credentials" -ForegroundColor Cyan
    $hits = kubectl -n $script:NS exec deploy/langgraph-agent -c agent -- env | Select-String -Pattern 'secret|password|cert'
    if ($hits) { $hits } else { "(none)" }
    Write-Host "`n=== Configuration the pod receives (IDs and endpoints only)" -ForegroundColor Cyan
    kubectl -n $script:NS get configmap langgraph-agent-config -o jsonpath='{.data}'
    Write-Host ""
}

function Show-Identity {
    Write-Host "=== Agent identity (claims only, never raw tokens)" -ForegroundColor Cyan
    kubectl -n $script:NS exec deploy/langgraph-agent -c agent -- python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8080/identity').read().decode())"
}

function Ask-Agent {
    Write-Host "=== Asking the agent (one allowed tool, one forbidden tool). Takes 10-20 seconds." -ForegroundColor Cyan
    kubectl -n $script:NS exec deploy/langgraph-agent -c agent -- python -c "import urllib.request,json;r=urllib.request.Request('http://localhost:8080/ask',data=json.dumps({'q':'Find the employee named Adele and tell me her job title. Then also try to list the directory security groups and tell me what happened.'}).encode());print(urllib.request.urlopen(r,timeout=120).read().decode())"
}

function Show-Spans {
    Write-Host "=== Agent 365 SDK spans from the last 3 minutes" -ForegroundColor Cyan
    kubectl -n $script:NS logs deploy/langgraph-agent -c agent --since=3m | Select-String '"span": "(invoke_agent|chat|execute_tool)' | ForEach-Object { $t = $_.ToString(); $t.Substring(0, [Math]::Min(150, $t.Length)) }
    Write-Host "`n=== Telemetry export errors (none is good)" -ForegroundColor Cyan
    $e = kubectl -n $script:NS logs deploy/langgraph-agent -c agent --since=3m | Select-String 'HTTP [0-9]{3}|non-retryable'
    if ($e) { $e } else { "(none)" }
}

function Test-DemoReady {
    Write-Host "Checking AWS sign-in..." -ForegroundColor Cyan
    aws sts get-caller-identity --query Arn --output text
    Write-Host "Checking cluster node..." -ForegroundColor Cyan
    kubectl get nodes
    Write-Host "Checking agent pod..." -ForegroundColor Cyan
    kubectl -n $script:NS get pods
}
