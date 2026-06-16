param(
    [string] $Repository = '',
    [string] $RepositoryUrl = '',
    [ValidateSet('private', 'public', 'internal')] [string] $Visibility = 'private',
    [string] $Branch = 'main',
    [string] $CommitMessage = 'Add VMware monitoring lab',
    [string] $GitUserName = '',
    [string] $GitUserEmail = '',
    [switch] $CreateRemote,
    [switch] $OpenInBrowser
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$sensitivePaths = @(
    '.terraform',
    'terraform.tfstate',
    'terraform.tfstate.backup',
    'terraform.tfvars',
    'workstation.auto.tfvars',
    'lab-build.log',
    'lab-build.status'
)

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments)] [string[]] $Arguments)

    & git -C $ProjectRoot @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Test-Command {
    param([Parameter(Mandatory)] [string] $Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

if (-not (Test-Command git)) {
    throw 'Git is not installed or is not on PATH.'
}

if (-not $RepositoryUrl -and $Repository) {
    $RepositoryUrl = "https://github.com/$Repository.git"
}

if ($CreateRemote -and -not $Repository) {
    throw 'Use -Repository owner/name when -CreateRemote is set.'
}

Push-Location $ProjectRoot
try {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot '.git'))) {
        Write-Host "Initializing git repository in $ProjectRoot"
        & git -C $ProjectRoot init -b $Branch
        if ($LASTEXITCODE -ne 0) {
            Invoke-Git init
            Invoke-Git branch -M $Branch
        }
    }
    else {
        Invoke-Git branch -M $Branch
    }

    if ($GitUserName) {
        Invoke-Git config user.name $GitUserName
    }
    if ($GitUserEmail) {
        Invoke-Git config user.email $GitUserEmail
    }

    $configuredName = (& git -C $ProjectRoot config user.name)
    $configuredEmail = (& git -C $ProjectRoot config user.email)
    if (-not $configuredName -or -not $configuredEmail) {
        throw "Git commit identity is not configured. Rerun with -GitUserName 'Your Name' -GitUserEmail 'you@example.com', or set git config --global user.name and user.email."
    }

    foreach ($path in $sensitivePaths) {
        $fullPath = Join-Path $ProjectRoot $path
        if (Test-Path -LiteralPath $fullPath) {
            & git -C $ProjectRoot check-ignore --quiet -- $path
            if ($LASTEXITCODE -ne 0) {
                throw "Refusing to continue because sensitive path is not ignored: $path"
            }
        }
    }

    Invoke-Git add .

    $stagedFiles = @(& git -C $ProjectRoot diff --cached --name-only)
    $blocked = @($stagedFiles | Where-Object {
        $_ -match '(^|/)terraform\.tfstate(\.backup)?$' -or
        $_ -match '(^|/)terraform\.tfvars$' -or
        $_ -match '(^|/)workstation\.auto\.tfvars$' -or
        $_ -match '(^|/)lab-build\.(log|status)$' -or
        $_ -match '\.(pem|key)$'
    })

    if ($blocked.Count -gt 0) {
        throw "Refusing to commit sensitive files:`n$($blocked -join "`n")"
    }

    if ($stagedFiles.Count -eq 0) {
        Write-Host 'No changes are staged for commit.'
    }
    else {
        Write-Host 'Files staged for commit:'
        $stagedFiles | ForEach-Object { Write-Host "  $_" }
        Invoke-Git commit -m $CommitMessage
    }

    if ($CreateRemote) {
        if (-not (Test-Command gh)) {
            throw 'GitHub CLI is not installed or is not on PATH. Install gh or rerun with -RepositoryUrl.'
        }

        $visibilityFlag = "--$Visibility"
        $createArgs = @('repo', 'create', $Repository, $visibilityFlag, '--source', $ProjectRoot, '--remote', 'origin')
        if ($OpenInBrowser) {
            $createArgs += '--web'
        }

        & gh @createArgs
        if ($LASTEXITCODE -ne 0) {
            throw "gh $($createArgs -join ' ') failed with exit code $LASTEXITCODE"
        }
    }
    elseif ($RepositoryUrl) {
        $remotes = @(& git -C $ProjectRoot remote)
        if ($remotes -contains 'origin') {
            Invoke-Git remote set-url origin $RepositoryUrl
        }
        else {
            Invoke-Git remote add origin $RepositoryUrl
        }
    }
    else {
        Write-Host 'No remote was configured. Pass -Repository owner/name -CreateRemote or -RepositoryUrl https://github.com/owner/repo.git.'
        return
    }

    Invoke-Git push -u origin $Branch
    Write-Host "Published $ProjectRoot to GitHub on branch $Branch"
}
finally {
    Pop-Location
}
