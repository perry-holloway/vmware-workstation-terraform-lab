param(
    [Parameter(Mandatory)] [string] $TemplateVmx,
    [Parameter(Mandatory)] [string] $DestinationRoot,
    [string] $VmrunPath = 'C:\Program Files\VMware\VMware Workstation\vmrun.exe',
    [string] $OutputTfvars = '',
    [string[]] $RefreshDisks = @(),
    [switch] $SkipHardwareChanges
)

$ErrorActionPreference = 'Stop'

if (-not $OutputTfvars) {
    $OutputTfvars = Join-Path (Split-Path -Parent $PSScriptRoot) 'workstation.auto.tfvars'
}

function Convert-ToHclPath {
    param([Parameter(Mandatory)] [string] $Path)
    return $Path.Replace('\', '/')
}

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

$template = (Resolve-Path -LiteralPath $TemplateVmx).Path
$vmrun = (Resolve-Path -LiteralPath $VmrunPath).Path
$destination = [System.IO.Path]::GetFullPath($DestinationRoot)
New-Item -ItemType Directory -Path $destination -Force | Out-Null

$templateDirectory = Split-Path -Parent $template
$templateDisk = (Get-Content -LiteralPath $template |
    Where-Object { $_ -match '^scsi0:0\.fileName\s*=' } |
    Select-Object -First 1) -replace '^.*=\s*"', '' -replace '"\s*$', ''
if (-not $templateDisk) {
    throw "Could not find scsi0:0.fileName in template VMX."
}
$templateVmdk = Join-Path $templateDirectory $templateDisk

$vms = @(
    @{ Name = 'prometheus'; Cpu = 2; MemoryMb = 4096 },
    @{ Name = 'kubernetes'; Cpu = 2; MemoryMb = 8192 },
    @{ Name = 'grafana'; Cpu = 2; MemoryMb = 4096 },
    @{ Name = 'jenkins'; Cpu = 2; MemoryMb = 4096 }
)

foreach ($vm in $vms) {
    $directory = Join-Path $destination $vm.Name
    $vmx = Join-Path $directory "$($vm.Name).vmx"
    # A monolithicSparse disk descriptor names its extent internally, so retain
    # the template disk basename when copying it into each isolated VM folder.
    $vmdk = Join-Path $directory $templateDisk
    if (Test-Path -LiteralPath $directory) {
        $unexpected = Get-ChildItem -LiteralPath $directory -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notin @($vmx, $vmdk) -and
                $_.Extension -notin @('.vmsd', '.vmxf', '.log', '.scoreboard', '.lck', '.vmem') -and
                $_.Name -ne 'nvram' -and
                $_.Name -notlike "$templateDisk.bad-*" -and
                $_.Name -ne "$($vm.Name).vmx.terraform-backup"
            }
        if ($unexpected) {
            throw "Destination VM directory is not empty: $directory"
        }
    }

    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    if ($RefreshDisks -contains $vm.Name) {
        $locks = @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like '*.lck' })
        if ($locks.Count -gt 0) {
            throw "Power off $($vm.Name) in VMware Workstation before refreshing its disk. Lock folder found: $($locks[0].FullName)"
        }

        if (Test-Path -LiteralPath $vmdk) {
            $backup = Join-Path $directory "$templateDisk.bad-$(Get-Date -Format 'yyyyMMddHHmmss')"
            Rename-Item -LiteralPath $vmdk -NewName (Split-Path -Leaf $backup)
            Write-Host "Renamed existing disk for $($vm.Name) to $backup"
        }

        Write-Host "Refreshing the template disk for $($vm.Name)..."
        Copy-Item -LiteralPath $templateVmdk -Destination $vmdk
    }
    elseif (-not (Test-Path -LiteralPath $vmdk)) {
        Write-Host "Copying the template disk for $($vm.Name)..."
        Copy-Item -LiteralPath $templateVmdk -Destination $vmdk
    }
    elseif ((Get-Item -LiteralPath $vmdk).Length -le 0) {
        throw "The existing disk copy is incomplete: $vmdk"
    }

    $prepareVmx = $false
    if (-not (Test-Path -LiteralPath $vmx)) {
        Copy-Item -LiteralPath $template -Destination $vmx
        $prepareVmx = $true
    }
    elseif ($RefreshDisks -contains $vm.Name) {
        $prepareVmx = $true
    }

    if ($prepareVmx) {
        $vmxContent = Get-Content -LiteralPath $vmx | Where-Object {
            $_ -notmatch '^(uuid\.|ethernet0\.generatedAddress|ethernet0\.generatedAddressOffset|vmci0\.id|cleanShutdown|softPowerOff|vm\.lastPowerRequestTimestamp)\s*='
        }
        Set-Content -LiteralPath $vmx -Value $vmxContent -Encoding ascii
        Set-VmxValue -Path $vmx -Key 'displayName' -Value $vm.Name
        Set-VmxValue -Path $vmx -Key 'scsi0:0.fileName' -Value $templateDisk
        Set-VmxValue -Path $vmx -Key 'sata0:1.present' -Value 'FALSE'
        Set-VmxValue -Path $vmx -Key 'sata0:1.startConnected' -Value 'FALSE'
        Set-VmxValue -Path $vmx -Key 'bios.bootOrder' -Value 'hdd'
    }

    $vm['Vmx'] = $vmx
}

$manageHardwareValue = if ($SkipHardwareChanges) { 0 } else { 1 }
& (Join-Path $PSScriptRoot 'Manage-WorkstationVMs.ps1') `
    -VmrunPath $vmrun `
    -PrometheusVmx $vms[0].Vmx `
    -KubernetesVmx $vms[1].Vmx `
    -GrafanaVmx $vms[2].Vmx `
    -JenkinsVmx $vms[3].Vmx `
    -ManageHardware $manageHardwareValue `
    -StartVms 1

foreach ($vm in $vms) {
    Write-Host "Waiting for VMware Tools to report the IP for $($vm.Name)..."
    $vm['Address'] = (& $vmrun -T ws getGuestIPAddress $vm.Vmx -wait).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $vm.Address) {
        throw "Could not obtain an IP address for $($vm.Name). Confirm open-vm-tools is installed in the template."
    }
}

$content = @"
manage_workstation_hardware = false
start_workstation_vms       = true

prometheus_vmx_path = "$(Convert-ToHclPath $vms[0].Vmx)"
kubernetes_vmx_path = "$(Convert-ToHclPath $vms[1].Vmx)"
grafana_vmx_path    = "$(Convert-ToHclPath $vms[2].Vmx)"
jenkins_vmx_path    = "$(Convert-ToHclPath $vms[3].Vmx)"

prometheus_vm = {
  name    = "prometheus"
  address = "$($vms[0].Address)"
}

kubernetes_vm = {
  name    = "kubernetes"
  address = "$($vms[1].Address)"
}

grafana_vm = {
  name    = "grafana"
  address = "$($vms[2].Address)"
}

jenkins_vm = {
  name    = "jenkins"
  address = "$($vms[3].Address)"
}
"@

Set-Content -LiteralPath $OutputTfvars -Value $content -Encoding ascii
Write-Host "Created four Workstation VMs and wrote $OutputTfvars"
Write-Host $content
