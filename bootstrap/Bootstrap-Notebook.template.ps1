# Bootstrap-Notebook.template.ps1
# TEMPLATE ONLY - copy to NAS as Bootstrap-Notebook.ps1 and fill in paths
# DO NOT COMMIT the live version
# NAS location: \\your-nas\Software\bootstrap\Bootstrap-Notebook.ps1
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
        GitHubUser  = 'KonradLanz'
        LocalBase   = $repoBase
        NasShare    = '\\your-nas\Software'   # <-- fill in
    }
    $cfg | Export-Clixml $configFile
}

# --- git ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host 'Installiere git...' -ForegroundColor Yellow
    winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path','User')
}

# --- Clone / pull repos ---
foreach ($repo in @('ExecutionPolicy-Foundation','windows-disk-transition-toolkit')) {
    $dir = Join-Path $cfg.LocalBase $repo
    if (-not (Test-Path $dir)) {
        Write-Host "Klone $repo..." -ForegroundColor Yellow
        git clone "https://$($cfg.GitHubToken)@github.com/$($cfg.GitHubUser)/${repo}.git" $dir
    } else {
        Write-Host "Aktualisiere $repo..." -ForegroundColor Cyan
        Push-Location $dir; git pull; Pop-Location
    }
}

# --- setup.ps1 ---
$setup = Join-Path $cfg.LocalBase 'windows-disk-transition-toolkit\setup.ps1'
if (Test-Path $setup) { & $setup }

# --- NAS verbinden ---
try { Remove-PSDrive -Name 'S' -Force -ErrorAction SilentlyContinue } catch {}
New-PSDrive -Name 'S' -PSProvider FileSystem -Root $cfg.NasShare -Credential $cred -Scope Global | Out-Null

Write-Host ''
Write-Host 'Bootstrap Notebook abgeschlossen.' -ForegroundColor Green
Write-Host "  Repos : $($cfg.LocalBase)" -ForegroundColor Yellow
Write-Host '  NAS   : S:\' -ForegroundColor Yellow
Write-Host ''
