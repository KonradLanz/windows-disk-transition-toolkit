# PowerShell Conventions — Windows Disk Transition Toolkit

Diese Datei dokumentiert gelernte Patterns und teure Bugfixes aus der Entwicklung.
Jede neue Funktion soll diese Conventions befolgen.

---

## 1. `$ErrorActionPreference = 'Stop'` + externe Befehle

**Problem:** `EAP=Stop` wirft `NativeCommandError` wenn externe Befehle (`net.exe`,
`robocopy`, `diskpart`, ...) etwas auf stderr schreiben — auch bei Erfolg.

**Lösung:** Alle externen Aufrufe über `Invoke-NetUse` oder ein analoges Wrapper-Pattern
routen, das EAP lokal auf `Continue` setzt und den ExitCode auswertet:

```powershell
function Invoke-NetUse {
    param([string[]]$NetArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & net.exe @NetArgs 2>&1
    $ec = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return [pscustomobject]@{ ExitCode = $ec; Output = $output }
}
```

**Niemals** direkt `& net.exe ...` unter `EAP=Stop` aufrufen.

---

## 2. Netzlaufwerke: `net use` statt `New-PSDrive`

**Problem:** `New-PSDrive` ohne `-Scope Global` ist nur in der aktuellen Funktion sichtbar.
Außerdem wirft `New-PSDrive` bei falschem Passwort eine terminierende Exception unter `EAP=Stop`.

**Lösung:** Immer `net use` via `Invoke-NetUse` verwenden. Das erzeugt ein echtes
Windows-Netzlaufwerk (sichtbar in Explorer, `net use`, allen Shells) und liefert einen
auswertbaren ExitCode zurück.

```powershell
# GUT
$r = Invoke-NetUse @('use', 'Z:', '\\server\share', $password, "/user:$user", '/persistent:no')
if ($r.ExitCode -ne 0) { <Fehlerbehandlung> }

# SCHLECHT — wirft Exception unter EAP=Stop, nur lokal sichtbar
New-PSDrive -Name Z -PSProvider FileSystem -Root '\\server\share' -Credential $cred
```

**Retry bei falschem Passwort:** `Connect-NasWithRetry` in `lib/Get-CredentialCache.ps1`
kapselt Credential-Cache + Retry-Logik. Immer diese Funktion verwenden statt direkter
`net use`-Aufrufe.

---

## 3. `break` in `switch` verlässt nicht die umgebende Schleife

**Problem:** In PowerShell verlässt `break` innerhalb eines `switch`-Blocks nur das
`switch`, nicht eine umgebende `do..while`- oder `while`-Schleife.

```powershell
# FALSCH — Schleife läuft weiter nach 'Q'
do {
    $choice = Read-Host 'Choice'
    switch ($choice) {
        'Q' { break }   # verlässt nur switch!
    }
} while ($choice -ne 'Q')  # wertet aus, läuft einen extra Durchlauf

# RICHTIG — $running-Flag
$running = $true
while ($running) {
    $choice = Read-Host 'Choice'
    switch ($choice) {
        'Q' { $running = $false }
    }
}
```

---

## 4. `Format-Table` → Datei: immer `Out-String -Width 4096`

**Problem:** `Out-String` hat ohne `-Width` standardmäßig 80 Zeichen Breite.
Jede `Format-Table | Out-String | Out-File`-Pipeline schneidet Spalten ab.

**Lösung:** Immer `-Width 4096` angeben wenn in Dateien geschrieben wird:

```powershell
# RICHTIG
$data | Format-Table -AutoSize | Out-String -Width 4096 | Out-File $path

# FALSCH — truncated auf 80 Zeichen
$data | Format-Table -AutoSize | Out-String | Out-File $path
```

Für **auswertbare Daten** immer zusätzlich `Export-Csv` schreiben — CSV wird nie truncated.

---

## 5. Funktionen die nur anzeigen sollen: kein `return $object`

**Problem:** PowerShell gibt jeden nicht-zugewiesenen Wert in die Pipeline.
Ein `return $map` am Ende einer Funktion die bereits `Format-Table` geschrieben hat,
gibt die Rohobjekte nochmals aus — auch nach dem Menü-Loop.

**Lösung:** Funktionen die nur für Side-Effects aufgerufen werden (Anzeige, Datei schreiben)
ohne `return` beenden, oder explizit `| Out-Null` am Ende.

```powershell
# RICHTIG
function Show-Something {
    $data | Format-Table -AutoSize  # gibt aus und ist fertig
}

# FALSCH — Objekte landen nach dem Menü in der Konsole
function Show-Something {
    $data | Format-Table -AutoSize
    return $data  # verursacht doppelten Output
}
```

---

## 6. Dateipfade aus Strings: Backslash in Regex escapen

**Problem:** `$special -replace '[\/:*?"<>| ]', '_'` escapt Backslash nicht.
`Recovery\WindowsRE` wird zu `Recovery\WindowsRE` statt `Recovery_WindowsRE`,
was beim Schreiben als Dateiname einen Unterordner-Pfad erzeugt.

**Lösung:** `\\` im Regex-Zeichensatz:

```powershell
$safe = $special -replace '[\\/:*?"<>| ]', '_'
```

---

## 7. NAS-Dateitransfer: `robocopy` statt `Copy-Item` für Netzwerkziele

**Problem:** `Copy-Item` auf Netzwerkfreigaben bricht bei `Das Netzwerk ist ausgelastet`
mit IOException ab. Kein automatischer Retry.

**Lösung:** `robocopy` mit Retry-Flags verwenden. ExitCode 0-7 ist Erfolg bei robocopy
(Bit-Flags: 0=kein Copy, 1=Dateien kopiert, 2=Extra, 4=Mismatched, ...). ExitCode >= 8 ist Fehler.

```powershell
$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
robocopy $src $dst /E /R:3 /W:5 /NP /NFL /NDL 2>&1 | Out-Null
$rc = $LASTEXITCODE
$ErrorActionPreference = $prev
if ($rc -ge 8) { Write-Host "[FEHLER] robocopy ExitCode $rc" -ForegroundColor Red }
```
