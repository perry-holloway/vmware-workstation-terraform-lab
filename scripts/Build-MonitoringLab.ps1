param(
    [string] $TemplateVmx = 'C:\VMs\Ubuntu-Template\Ubuntu-Template.vmx',
    [string] $DestinationRoot = 'C:\VMs\Monitoring-Lab',
    [string] $TerraformPath = '',
    [switch] $RefreshKubernetesDisk,
    [switch] $RefreshJenkinsDisk,
    [switch] $SkipHardwareChanges
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path $projectRoot 'lab-build.log'
$statusPath = Join-Path $projectRoot 'lab-build.status'

if (-not $TerraformPath) {
    $terraformCommand = Get-Command terraform -ErrorAction SilentlyContinue
    if ($terraformCommand) {
        $TerraformPath = $terraformCommand.Source
    }
}

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

    if (-not $TerraformPath -or -not (Test-Path -LiteralPath $TerraformPath)) {
        throw "Terraform executable not found. Install Terraform, add it to PATH, or pass -TerraformPath."
    }

    Set-Location -LiteralPath $projectRoot
    & $TerraformPath apply -auto-approve
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
