<#
.SYNOPSIS
  Prepares a Windows machine to run Demo 2 (installs Azure CLI, AWS CLI, kubectl, eksctl). Safe to re-run.
.DESCRIPTION
  Run in an ELEVATED PowerShell window (Run as administrator), or via Azure run-command (runs as SYSTEM).
  Installs only what is missing. After it finishes, open a NEW terminal window so the tools are on PATH.
#>
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$bin = "C:\Tools\bin"
$tmp = Join-Path $env:TEMP "demo2-setup"
New-Item -ItemType Directory -Force -Path $bin, $tmp | Out-Null

function Have($exe, $extra) {
    if (Get-Command $exe -ErrorAction SilentlyContinue) { return $true }
    return ($extra -and (Test-Path $extra))
}
function AddToMachinePath($p) {
    $cur = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if (($cur -split ";") -notcontains $p) {
        [Environment]::SetEnvironmentVariable("Path", "$cur;$p", "Machine")
        Write-Host "Added $p to the machine PATH"
    }
}
function InstallMsi($name, $url, $file) {
    $path = Join-Path $tmp $file
    Write-Host "Downloading $name ..."
    Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
    Write-Host "Installing $name ..."
    $p = Start-Process msiexec.exe -ArgumentList "/i `"$path`" /qn /norestart" -Wait -PassThru
    if ($p.ExitCode -notin 0, 3010) { throw "$name installer failed with exit code $($p.ExitCode)" }
}

Write-Host "=== Azure CLI"
if (Have az "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd") { Write-Host "already installed" }
else { InstallMsi "Azure CLI" "https://aka.ms/installazurecliwindowsx64" "azure-cli.msi" }

Write-Host "=== AWS CLI"
if (Have aws "C:\Program Files\Amazon\AWSCLIV2\aws.exe") { Write-Host "already installed" }
else { InstallMsi "AWS CLI" "https://awscli.amazonaws.com/AWSCLIV2.msi" "awscli.msi" }

Write-Host "=== kubectl"
if (Have kubectl "$bin\kubectl.exe") { Write-Host "already installed" }
else {
    Write-Host "Downloading kubectl ..."
    Invoke-WebRequest -Uri "https://dl.k8s.io/release/v1.34.0/bin/windows/amd64/kubectl.exe" -OutFile "$bin\kubectl.exe" -UseBasicParsing
}

Write-Host "=== eksctl"
if (Have eksctl "$bin\eksctl.exe") { Write-Host "already installed" }
else {
    Write-Host "Downloading eksctl ..."
    $zip = Join-Path $tmp "eksctl.zip"
    Invoke-WebRequest -Uri "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Windows_amd64.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $bin -Force
}

AddToMachinePath $bin
AddToMachinePath "C:\Program Files\Amazon\AWSCLIV2"

Write-Host "=== TLS inspection certificate (only acts if the machine is behind Entra Global Secure Access)"
& (Join-Path $PSScriptRoot "fix-tls-inspection.ps1")

Write-Host "=== PowerShell script permission"
try { Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force } catch { Write-Host "Could not set execution policy: $($_.Exception.Message)" }

Write-Host "`n=== Versions"
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
& "$bin\kubectl.exe" version --client 2>&1 | Select-Object -First 1
& "$bin\eksctl.exe" version 2>&1 | Select-Object -First 1
if (Test-Path "C:\Program Files\Amazon\AWSCLIV2\aws.exe") { & "C:\Program Files\Amazon\AWSCLIV2\aws.exe" --version }
if (Test-Path "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd") { & "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd" version --query '\"azure-cli\"' -o tsv 2>&1 | Select-Object -First 1 }
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "`nSetup complete. Open a NEW terminal window before using the tools." -ForegroundColor Green
