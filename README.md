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

Das Script installiert `git` automatisch, klont beide Repos nach `%USERPROFILE%\github\` und zeigt den naechsten Schritt.

### Mit NAS direkt verbinden

```powershell
$s = 'https://raw.githubusercontent.com/KonradLanz/windows-disk-transition-toolkit/main/Bootstrap-HpPro.ps1'
& ([scriptblock]::Create((New-Object Net.WebClient).DownloadString($s))) -NasShare '\\<nas-hostname>\<share>'
```

> `<nas-hostname>` und `<share>` durch eigenen NAS-Pfad ersetzen.

---

## Truncation-Suche starten

Nach dem Bootstrap (NAS bereits als Z: gemountet):

```powershell
cd "$env:USERPROFILE\github\windows-disk-transition-toolkit"
.\tools\Search-Truncations.ps1 -Dirs @('ordner-1','ordner-2')
```

Oder mit NAS-Mount in einem Schritt:

```powershell
cd "$env:USERPROFILE\github\windows-disk-transition-toolkit"
.\tools\Search-Truncations.ps1 `
    -NasShare '\\<nas-hostname>\<share>' `
    -SearchBase 'ISOs\Windows10HpPro' `
    -Dirs @('ordner-1','ordner-2')
```

Der Bericht wird automatisch nach `%TEMP%\truncation-report.csv` gespeichert.

---

## Vom USB-Stick starten (kein Internet noetig)

1. Repo als ZIP von GitHub laden, auf Stick entpacken
2. PowerShell als Admin:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
& 'D:\windows-disk-transition-toolkit\Bootstrap-HpPro.ps1'
```

> Laufwerksbuchstaben (`D:`) je nach Stick anpassen.

---

## Was das Bootstrap macht

| Schritt | Aktion |
|---|---|
| 1 | PS-Version anzeigen |
| 2 | winget pruefen |
| 3 | git installieren falls fehlt |
| 4 | Repos nach `%USERPROFILE%\github\` klonen / aktualisieren |
| 5 | NAS mounten (optional, per `-NasShare` Parameter) |

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
| `*.ps1` | PS 5.1 kompatibel (Standard, laeuft ueberall) |
| `*.pwsh7.ps1` | Benoetigt pwsh.exe >= 7.x |
| `*.pwsh74.ps1` | Benoetigt pwsh.exe >= 7.4 LTS |

---

## Herbst 2026 - Ubuntu Migration

Nach Ende Windows 10 Support: Wechsel auf Ubuntu.  
Neue SSD einbauen, Multiboot Windows 11 + Ubuntu, dann WSL2 + Docker.
