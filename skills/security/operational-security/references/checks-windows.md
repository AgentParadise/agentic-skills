# Windows read-only checks (PowerShell, non-admin unless noted)

## Posture
```powershell
Get-ComputerInfo | Select OsName, OsVersion, OsBuildNumber
dsregcmd /status | Select-String 'AzureAdJoined|DomainJoined|MdmUrl'     # managed?
manage-bde -status C:            # BitLocker (admin)
Get-NetFirewallProfile | Select Name, Enabled
Get-MpComputerStatus | Select AMServiceEnabled, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated
Get-HotFix | Sort InstalledOn -Desc | Select -First 5
Confirm-SecureBootUEFI
```
Pending updates: `(New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher().Search('IsInstalled=0').Updates | Select Title`.

## Exposure
```powershell
Get-NetTCPConnection -State Listen | Where LocalAddress -notin '127.0.0.1','::1' |
  Select LocalAddress, LocalPort, @{n='Proc';e={(Get-Process -Id $_.OwningProcess).Name}}
```

## Persistence
```powershell
Get-CimInstance Win32_StartupCommand | Select Name, Command, Location
Get-ScheduledTask | Where { $_.Date -gt (Get-Date).AddDays(-14) } | Select TaskName, TaskPath
Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run, HKLM:\Software\Microsoft\Windows\CurrentVersion\Run
Get-Service | Where StartType -eq Automatic | Where Status -eq Running
```

## Installs and extensions
`Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, HKCU:\...\Uninstall\* | Sort InstallDate -Desc | Select -First 20 DisplayName, InstallDate`. Chromium extensions under `%LOCALAPPDATA%\<Vendor>\<Browser>\User Data\<Profile>\Extensions`.

On managed Windows, Defender/EDR owns detection: read its status, never change exclusions or tamper settings.
