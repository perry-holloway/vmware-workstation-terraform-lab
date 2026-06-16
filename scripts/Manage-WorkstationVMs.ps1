param(
    [Parameter(Mandatory)] [string] $VmrunPath,
    [Parameter(Mandatory)] [string] $PrometheusVmx,
    [Parameter(Mandatory)] [string] $KubernetesVmx,
    [Parameter(Mandatory)] [string] $GrafanaVmx,
    [Parameter(Mandatory)] [string] $JenkinsVmx,
    [Parameter(Mandatory)] [ValidateSet(0, 1)] [int] $ManageHardware,
    [Parameter(Mandatory)] [ValidateSet(0, 1)] [int] $StartVms
)

$ErrorActionPreference = 'Stop'

function Set-VmxValue {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Key,
        [Parameter(Mandatory)] [string] $Value
    )

    $content = Get-Content -LiteralPath $Path
    $pattern = '^' + [regex]::Escape($Key) + '\s*='
    $replacement = "$Key = `"$Value`""

    if ($content -match $pattern) {
        $content = $content | ForEach-Object {
            if ($_ -match $pattern) { $replacement } else { $_ }
        }
    }
    else {
        $content += $replacement
    }

    Set-Content -LiteralPath $Path -Value $content -Encoding ascii
}

function Get-RunningVms {
    $result = & $VmrunPath -T ws list
    if ($LASTEXITCODE -ne 0) {
        throw "vmrun could not list VMware Workstation VMs."
    }

    return @($result | Select-Object -Skip 1 | ForEach-Object {
        try { (Resolve-Path -LiteralPath $_).Path } catch { $_ }
    })
}

function Set-WorkstationVm {
    param(
        [Parameter(Mandatory)] [string] $VmxPath,
        [Parameter(Mandatory)] [int] $Cpu,
        [Parameter(Mandatory)] [int] $MemoryMb,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $RunningVms
    )

    $resolved = (Resolve-Path -LiteralPath $VmxPath).Path
    $isRunning = $RunningVms -contains $resolved

    if ($ManageHardware) {
        if ($isRunning) {
            throw "Power off this VM before Terraform changes its hardware: $resolved"
        }

        Copy-Item -LiteralPath $resolved -Destination "$resolved.terraform-backup" -Force
        Set-VmxValue -Path $resolved -Key 'numvcpus' -Value $Cpu
        Set-VmxValue -Path $resolved -Key 'memsize' -Value $MemoryMb
        Write-Host "Configured $resolved with $Cpu CPU and $MemoryMb MB RAM"
    }

    if ($StartVms -and -not $isRunning) {
        & $VmrunPath -T ws start $resolved nogui
        if ($LASTEXITCODE -ne 0) {
            throw "vmrun failed to start $resolved"
        }
        Write-Host "Started $resolved in headless mode"
    }
}

$resolvedVmrun = (Resolve-Path -LiteralPath $VmrunPath).Path
$VmrunPath = $resolvedVmrun
$running = @(Get-RunningVms)

Set-WorkstationVm -VmxPath $PrometheusVmx -Cpu 2 -MemoryMb 4096 -RunningVms $running
Set-WorkstationVm -VmxPath $KubernetesVmx -Cpu 2 -MemoryMb 8192 -RunningVms $running
Set-WorkstationVm -VmxPath $GrafanaVmx -Cpu 2 -MemoryMb 4096 -RunningVms $running
Set-WorkstationVm -VmxPath $JenkinsVmx -Cpu 2 -MemoryMb 4096 -RunningVms $running
