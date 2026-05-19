# config.sample.ps1
# Copy this file to config.local.ps1 and fill in your values.
# config.local.ps1 is excluded from git via .gitignore.

$cfg = [pscustomobject]@{
    NasShare    = "\\\\your-nas\\Software"          # NAS share root
    NasTarget   = "ISOs\\Windows10HpPro"             # Subfolder on NAS for reports
    DriveLetter = "Z"                                # Drive letter for NAS mapping
    LocalTemp   = "C:\\Temp"                          # Local temp for intermediate output
    GitHubUser  = "your-github-username"
    GitHubRepo  = "windows-disk-transition-toolkit"
    LocalBase   = "C:\\Tools"                         # Where repos are cloned
}
