param(
    [string] $IsoPath = 'C:\Users\hollowayps\Downloads\ubuntu-26.04-live-server-amd64.iso',
    [string] $DestinationDirectory = 'C:\VMs\Ubuntu-Template',
    [string] $VmName = 'Ubuntu-Template',
    [string] $VdiskManagerPath = 'C:\Program Files\VMware\VMware Workstation\vmware-vdiskmanager.exe',
    [string] $VmrunPath = 'C:\Program Files\VMware\VMware Workstation\vmrun.exe',
    [int] $DiskSizeGb = 50,
    [switch] $StartInstaller
)

$ErrorActionPreference = 'Stop'

$iso = (Resolve-Path -LiteralPath $IsoPath).Path
$vdiskManager = (Resolve-Path -LiteralPath $VdiskManagerPath).Path
$vmrun = (Resolve-Path -LiteralPath $VmrunPath).Path
$destination = [System.IO.Path]::GetFullPath($DestinationDirectory)
$vmx = Join-Path $destination "$VmName.vmx"
$vmdk = Join-Path $destination "$VmName.vmdk"

if (Test-Path -LiteralPath $destination) {
    if (Get-ChildItem -LiteralPath $destination -Force -ErrorAction SilentlyContinue) {
        throw "The template destination is not empty: $destination"
    }
}
else {
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
}

& $vdiskManager -c -s "${DiskSizeGb}GB" -a lsilogic -t 0 $vmdk
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create the template virtual disk."
}

$escapedIso = $iso.Replace('\', '\\')
$escapedDisk = (Split-Path -Leaf $vmdk).Replace('\', '\\')

$vmxContent = @"
.encoding = "windows-1252"
config.version = "8"
virtualHW.version = "21"
displayName = "$VmName"
guestOS = "ubuntu-64"
firmware = "efi"
numvcpus = "2"
cpuid.coresPerSocket = "1"
memsize = "4096"
mem.hotadd = "TRUE"
vcpu.hotadd = "TRUE"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"
scsi0.present = "TRUE"
scsi0.virtualDev = "lsilogic"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "$escapedDisk"
sata0.present = "TRUE"
sata0:1.present = "TRUE"
sata0:1.startConnected = "TRUE"
sata0:1.deviceType = "cdrom-image"
sata0:1.fileName = "$escapedIso"
bios.bootOrder = "cdrom,hdd"
bios.bootDelay = "3000"
ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "e1000e"
ethernet0.addressType = "generated"
usb.present = "TRUE"
ehci.present = "TRUE"
sound.present = "FALSE"
floppy0.present = "FALSE"
svga.autodetect = "TRUE"
tools.syncTime = "FALSE"
"@

Set-Content -LiteralPath $vmx -Value $vmxContent -Encoding ascii
Write-Host "Created clean Ubuntu template VM: $vmx"

if ($StartInstaller) {
    & $vmrun -T ws start $vmx gui
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start the Ubuntu installer VM."
    }
}
