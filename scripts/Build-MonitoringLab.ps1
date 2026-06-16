param(
    [string] $TemplateVmx = 'C:\VMs\Ubuntu-Template\Ubuntu-Template.vmx',
    [string] $DestinationRoot = 'C:\Users\hollowayps\Documents\Codex\VMs\Monitoring-Lab',
    [switch] $RefreshKubernetesDisk,
    [switch] $RefreshJenkinsDisk,
    [switch] $SkipHardwareChanges
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path $projectRoot 'lab-build.log'
$statusPath = Join-Path $projectRoot 'lab-build.status'
$terraform = 'C:\Users\hollowayps\AppData\Local\Microsoft\WinGet\Packages\Hashicorp.Terraform_Microsoft.Winget.Source_8wekyb3d8bbwe\terraform.exe'

Set-Content -LiteralPath $statusPath -Value 'RUNNING' -Encoding ascii
Start-Transcript -LiteralPath $logPath -Force | Out-Null

try {
    $labArgs = @{
        TemplateVmx      = $TemplateVmx
        DestinationRoot  = $DestinationRoot
    }

    if ($SkipHardwareChanges) {
        $labArgs.SkipHardwareChanges = $true
    }

    if ($RefreshKubernetesDisk) {
        $labArgs.RefreshDisks = @('kubernetes')
        $labArgs.SkipHardwareChanges = $true
    }
    if ($RefreshJenkinsDisk) {
        if ($labArgs.ContainsKey('RefreshDisks')) {
            $labArgs.RefreshDisks += 'jenkins'
        }
        else {
            $labArgs.RefreshDisks = @('jenkins')
        }
        $labArgs.SkipHardwareChanges = $true
    }

    & (Join-Path $PSScriptRoot 'New-WorkstationLab.ps1') @labArgs

    if (-not (Test-Path -LiteralPath $terraform)) {
        throw "Terraform executable not found: $terraform"
    }

    Set-Location -LiteralPath $projectRoot
    & $terraform apply -auto-approve
    if ($LASTEXITCODE -ne 0) {
        throw "terraform apply failed with exit code $LASTEXITCODE"
    }

    Set-Content -LiteralPath $statusPath -Value 'COMPLETE' -Encoding ascii
    Write-Host 'Monitoring lab build completed successfully.' -ForegroundColor Green
}
catch {
    Set-Content -LiteralPath $statusPath -Value "FAILED`r`n$($_.Exception.Message)" -Encoding ascii
    Write-Error $_
    exit 1
}
finally {
    Stop-Transcript | Out-Null
}
