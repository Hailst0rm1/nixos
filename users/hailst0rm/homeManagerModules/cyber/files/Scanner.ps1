# Port-Scanner.ps1
# Tests connectivity to specified ports on target hosts

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetHost,
    
    [Parameter(Mandatory=$false)]
    [int[]]$Ports,
    
    [Parameter(Mandatory=$false)]
    [string]$PortRange,
    
    [Parameter(Mandatory=$false)]
    [int]$Timeout = 1000
)

Write-Host "`nTesting ports on $TargetHost...`n" -ForegroundColor Cyan

# Build port list
$portList = @()

# If PortRange is specified, parse it
if ($PortRange) {
    if ($PortRange -match '^(\d+)-(\d+)$') {
        $startPort = [int]$Matches[1]
        $endPort = [int]$Matches[2]
        
        if ($startPort -gt $endPort) {
            Write-Host "Error: Start port must be less than end port" -ForegroundColor Red
            exit
        }
        
        $portList += $startPort..$endPort
    }
    else {
        Write-Host "Error: Invalid port range format. Use format: 8000-8050" -ForegroundColor Red
        exit
    }
}

# Add individual ports if specified
if ($Ports) {
    $portList += $Ports
}

# If no ports specified, use defaults
if ($portList.Count -eq 0) {
    $portList = @(21,22,23,25,53,80,110,143,443,445,3389,5985,5986,8080,8443)
}

# Remove duplicates and sort
$portList = $portList | Select-Object -Unique | Sort-Object

Write-Host "Scanning $($portList.Count) port(s)...`n" -ForegroundColor Cyan

$results = @()

foreach ($port in $portList) {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $connect = $tcpClient.BeginConnect($TargetHost, $port, $null, $null)
    $wait = $connect.AsyncWaitHandle.WaitOne($Timeout, $false)
    
    if ($wait) {
        try {
            $tcpClient.EndConnect($connect)
            $status = "Open"
            $color = "Green"
        }
        catch {
            $status = "Closed/Filtered"
            $color = "Red"
        }
    }
    else {
        $status = "Filtered/Blocked"
        $color = "Yellow"
    }
    
    $tcpClient.Close()
    
    $result = [PSCustomObject]@{
        Port = $port
        Status = $status
    }
    $results += $result
    
    Write-Host "Port $port : $status" -ForegroundColor $color
}

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Open ports: $(($results | Where-Object {$_.Status -eq 'Open'}).Count)" -ForegroundColor Green
Write-Host "Blocked/Filtered ports: $(($results | Where-Object {$_.Status -ne 'Open'}).Count)" -ForegroundColor Red
