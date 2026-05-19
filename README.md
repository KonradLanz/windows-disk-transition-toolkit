# windows-disk-transition-toolkit

PowerShell toolkit for disk analysis, eSATA export, NAS copy and HP Pro bootstrap.

**Upstream:** [KonradLanz/ExecutionPolicy-Foundation](https://github.com/KonradLanz/ExecutionPolicy-Foundation)

## Structure

```
windows-disk-transition-toolkit/
├── Start.bat                          ← Entry point (runs Start.ps1 elevated)
├── Start.ps1                          ← Main menu
├── setup.ps1                          ← First-run local config
├── config.sample.ps1                  ← Template — copy to config.local.ps1
└── lib/
    ├── Get-CredentialCache.ps1        ← NAS credential caching
    ├── Get-DiskPartitionMap.ps1       ← Disk/partition/volume mapping
    ├── Invoke-NotebookEsataExport.ps1 ← Notebook eSATA (Disk 1) export
    ├── Invoke-HpProCompare.ps1        ← HP Pro disk compare + NAS copy
    └── Copy-ReportsToNas.ps1          ← Copy local reports to NAS
```

## Bootstrap after reinstall

```cmd
powershell -ExecutionPolicy Bypass -Command "& {iex ((New-Object Net.WebClient).DownloadString('\\\\nas-hostname-removed\\Software\\bootstrap\\Bootstrap-HpPro.ps1'))}"
```

Or from an already running PowerShell session:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm 'https://raw.githubusercontent.com/KonradLanz/ExecutionPolicy-Foundation/main/StartWithGithub.ps1' | iex
```

## What stays on the NAS (not in this repo)

```
\\nas-hostname-removed\Software\bootstrap\
├── Bootstrap-HpPro.ps1
└── Bootstrap-Notebook.ps1
```

These files may contain local share paths and cached credentials — never commit them.

## Security

- No passwords, tokens or share paths are stored in this repo.
- NAS credentials are cached per-user/per-machine via `Export-Clixml` (DPAPI-protected).
- GitHub PAT is cached in `%APPDATA%\WDT-Bootstrap\config.xml` (DPAPI-protected).
- `config.local.ps1` and `*.xml` are excluded via `.gitignore`.
