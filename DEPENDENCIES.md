# Abhaengigkeiten & Lizenzhinweise

## Upstream: ExecutionPolicy-Foundation

Dieses Repo baut auf Skripten und Konventionen aus
**[KonradLanz/ExecutionPolicy-Foundation](https://github.com/KonradLanz/ExecutionPolicy-Foundation)** auf.

| Aspekt | Detail |
|---|---|
| Beziehung | Downstream-Projekt (nutzt Foundation-Funktionen via `irm \| iex`) |
| Sync-Mechanismus | Manuell — Foundation-Aenderungen werden bei Bedarf uebernommen |
| Lizenz Foundation | MIT (siehe dort) |
| Lizenz dieses Repos | MIT (siehe [LICENSE](LICENSE)) |

Beide Repos stehen unter MIT — es gibt keine Lizenz-Inkompatibilitaet.
Synced Files tragen den Kommentar `# Synced from KonradLanz/ExecutionPolicy-Foundation`.

---

## Abhaengigkeiten zur Laufzeit

| Tool | Zweck | Pflicht? | Bezug |
|---|---|---|---|
| `git` | Versionskontrolle, Skript-Bootstrap | Ja | winget install --id Git.Git |
| PowerShell 5.1+ | Ausfuehren aller `.ps1` Skripte | Ja | Windows-Inbox |
| `diskpart` | Disk-Analyse | Ja | Windows-Inbox |
| `robocopy` | Datei-Transfer NAS | Ja | Windows-Inbox |
| Python 3 + pip | git-filter-repo (History-Bereinigung) | Nein | winget install --id Python.Python.3.13 |

---

## Verwandte Repos

| Repo | Zweck |
|---|---|
| [ExecutionPolicy-Foundation](https://github.com/KonradLanz/ExecutionPolicy-Foundation) | PS Execution-Policy Grundlagen, Credential-Helpers |
| [git-history-tools](https://github.com/KonradLanz/git-history-tools) | History-Bereinigung (Hostnamen, Secrets entfernen) |
