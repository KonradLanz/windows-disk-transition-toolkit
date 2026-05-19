# Bootstrap-Notebook.template.ps1
# TEMPLATE ONLY - copy to NAS and fill in your values
# DO NOT COMMIT the live version
#
# PS 5.1 compatible (*.ps1 baseline)

$ErrorActionPreference = 'Stop'
$repoBase   = Join-Path $env:USERPROFILE 'github'
$cacheDir   = Join-Path $env:APPDATA 'WDT-Bootstrap'
$credFile   = Join-Path $cacheDir 'nas.xml'
$configFile = Join-Path $cacheDir 'config.xml'

New-Item -Path $cacheDir -ItemType Directory -Force | Out-Null
New-Item -Path $repoBase -ItemType Directory -Force | Out-Null

# --- NAS credentials ---
if (Test-Path $credFile) {
    try {
        $cred = Import-Clixml $credFile
        Write-Host 'NAS-Credentials aus Cache.' -ForegroundColor Cyan
    } catch {
        Remove-Item $credFile -Force
        $cred = Get-Credential -Message 'NAS-Zugangsdaten'
        $cred | Export-Clixml $credFile
    }
} else {
    $cred = Get-Credential -Message 'NAS-Zugangsdaten (werden lokal gecacht)'
    $cred | Export-Clixml $credFile
}

# --- GitHub config ---
if (Test-Path $configFile) {
    $cfg = Import-Clixml $configFile
} else {
    $cfg = [pscustomobject]@{
        GitHubToken = Read-Host 'GitHub PAT (wird lokal gecacht)'
        GitHubUser  = Read-Host 'GitHub Username'
        LocalBase   = $repoBase
        NasShare    = Read-Host 'NAS Share (z.B. \\\\nas\\Software)'
    }
    $cfg | Export-Clixml $configFile
}

# --- git ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path','User')
}

# --- Clone / pull repos ---
foreach ($repo in @('ExecutionPolicy-Foundation','windows-disk-transition-toolkit')) {
    $dir = Join-Path $cfg.LocalBase $repo
    if (-not (Test-Path $dir)) {
        git clone "https://$($cfg.GitHubToken)@github.com/$($cfg.GitHubUser)/${repo}.git" $dir
    } else {
        Push-Location $dir; git pull; Pop-Location
    }
}

# --- NAS verbinden ---
try { Remove-PSDrive -Name 'Z' -Force -ErrorAction SilentlyContinue } catch {}
New-PSDrive -Name 'Z' -PSProvider FileSystem -Root $cfg.NasShare -Credential $cred -Scope Global | Out-Null

Write-Host ''
Write-Host 'Bootstrap abgeschlossen.' -ForegroundColor Green
Write-Host "  Repos : $($cfg.LocalBase)" -ForegroundColor Yellow
Write-Host '  NAS   : Z:\' -ForegroundColor Yellow
