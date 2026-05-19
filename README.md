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

### Schritt 3a - Bootstrap vom NAS starten (empfohlen)

Wenn das NAS bereits als `Z:` gemountet ist:

```powershell
.\Bootstrap-HpPro.ps1
```

Oder direkt vom NAS (Z: wird dabei neu gemountet):

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
& 'Z:\bootstrap\Bootstrap-HpPro.ps1'
```

### Schritt 3b - Bootstrap von GitHub starten (Repo muss public sein)

```powershell
iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/KonradLanz/windows-disk-transition-toolkit/main/Bootstrap-HpPro.ps1'))
```

Das Script installiert `git` automatisch, klont beide Repos nach `%USERPROFILE%\github\` und zeigt den naechsten Schritt.

### Mit NAS-Mount in einem Schritt

```powershell
.\Bootstrap-HpPro.ps1 -NasShare "\\nas-hostname\sharename"
```

> **Wichtig - Backslash-Syntax:** Genau **zwei** Backslashes vorne, **kein** Backslash am Ende.
> - ✅ Richtig:  `"\\nas.example.com\Software"`
> - ❌ Falsch:  `"\\\\nas.example.com\\Software\"`  (zu viele Backslashes)
> - ❌ Falsch:  `"\\nas.example.com\Software\"`    (Backslash am Ende)

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
    -NasShare "\\nas-hostname\sharename" `
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
| 3 | git installieren falls fehlt (nach Install: PS neu starten, dann nochmal starten) |
| 4 | Repos nach `%USERPROFILE%\github\` klonen / aktualisieren |
| 5 | NAS mounten (optional, per `-NasShare` Parameter) |

---

## Dateistruktur

```
windows-disk-transition-toolkit/
├── Bootstrap-HpPro.ps1          <- Hier starten (lokal oder vom NAS)
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
