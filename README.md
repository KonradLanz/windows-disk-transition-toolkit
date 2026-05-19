# windows-disk-transition-toolkit

PowerShell-Toolkit fuer den Wechsel von alter HDD auf neue SSD unter Windows 10/11.  
Ziel: **Alte Platte raus, SSD rein, Computer wieder schnell.**

**Baseline: PowerShell 5.1** - auf jedem Windows 10/11 ohne Installation verfuegbar.

---

## Schnellstart (Copy-Paste)

### Schritt 1 - PowerShell als Administrator oeffnen

```
Windows-Taste -> PowerShell -> Rechtsklick -> Als Administrator ausfuehren
```

### Schritt 2 - Einmalig erlauben

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

### Schritt 3 - Bootstrap starten

```powershell
iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/KonradLanz/windows-disk-transition-toolkit/main/Bootstrap-HpPro.ps1'))
```

Das Script:
- installiert `git` automatisch (via winget)
- klont beide Repos nach `C:\Users\<name>\github\`
- mountet optional das NAS

### Mit NAS direkt verbinden

```powershell
$s = 'https://raw.githubusercontent.com/KonradLanz/windows-disk-transition-toolkit/main/Bootstrap-HpPro.ps1'
& ([scriptblock]::Create((New-Object Net.WebClient).DownloadString($s))) -NasShare '\\nas.ad.own.dedyn.io\Software'
```

---

## Truncation-Suche starten

Nach dem Bootstrap (Z: bereits gemountet):

```powershell
cd "$env:USERPROFILE\github\windows-disk-transition-toolkit"
.\tools\Search-Truncations.ps1 -Dirs @('esata-disk1-analysis_20260519-230954','analysis_20260519-224759')
```

Oder mit NAS-Mount in einem Schritt:

```powershell
.\tools\Search-Truncations.ps1 `
    -NasShare '\\nas.ad.own.dedyn.io\Software' `
    -SearchBase 'ISOs\Windows10HpPro' `
    -Dirs @('esata-disk1-analysis_20260519-230954','analysis_20260519-224759')
```

---

## Vom USB-Stick starten (kein Internet noetig)

1. Repo als ZIP von GitHub laden, auf Stick entpacken
2. PowerShell als Admin:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
& 'E:\windows-disk-transition-toolkit\Bootstrap-HpPro.ps1'
```

> `E:` je nach Stick-Laufwerksbuchstabe anpassen.

---

## Was das Bootstrap macht

| Schritt | Aktion |
|---|---|
| 1 | PS-Version anzeigen |
| 2 | winget pruefen |
| 3 | git installieren falls fehlt |
| 4 | Repos klonen / aktualisieren |
| 5 | NAS mounten (optional) |

---

## Dateistruktur

```
windows-disk-transition-toolkit/
├── Bootstrap-HpPro.ps1          <- Hier starten
├── tools/
│   └── Search-Truncations.ps1  <- Truncation-Suche auf NAS
├── bootstrap/
│   ├── Bootstrap-HpPro.template.ps1
│   └── Bootstrap-Notebook.template.ps1
└── lib/
    └── Test-PSEnvironment.ps1
```

---

## Naming Convention

| Suffix | Bedeutung |
|---|---|
| `*.ps1` | PS 5.1 kompatibel (Standard) |
| `*.pwsh7.ps1` | Benoetigt pwsh.exe >= 7.x |
| `*.pwsh74.ps1` | Benoetigt pwsh.exe >= 7.4 LTS |

---

## Herbst 2026 - Ubuntu Migration

Nach Ende Windows 10 Support: Wechsel auf Ubuntu.  
Neue SSD einbauen, Multiboot Windows 11 + Ubuntu, dann WSL2 + Docker.
