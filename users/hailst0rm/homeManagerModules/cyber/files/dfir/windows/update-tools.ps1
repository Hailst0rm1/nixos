<#
.SYNOPSIS
  Converge a FLARE/DFIR Windows VM to a declarative YAML manifest.

.DESCRIPTION
  nixos-rebuild-style reconcile for Chocolatey / VM-Packages:
    * installs packages in the manifest that are missing,
    * upgrades "latest" packages / installs pinned exact versions,
    * UNINSTALLS packages that were installed by a previous run of this
      script but have since been removed from the manifest.

  Generation-scoped prune (the safe part): the script only ever removes
  packages it recorded in its own state file. FLARE's base install and
  anything you installed by hand are never touched.

  ponytail: reconcile governs only choco/VM-Packages installs. Tools installed
  outside choco (manual .exe, direct Get-ZimmermanTools, pip) are not pruned —
  keep those in the manifest's source or manage them separately. Upgrade path:
  generate config.xml FROM this manifest so one file is the single source of
  truth for both build-time and runtime (design decision "C, later").

.PARAMETER Manifest
  Path to the YAML manifest (default: tools.yaml next to this script — which is
  where dfir-prepare-variant stages the variant's manifest before the build
  copies both onto the guest Desktop).

.PARAMETER DryRun
  Print the install / upgrade / remove plan and exit without changing anything.
#>
[CmdletBinding()]
param(
    [string]$Manifest = (Join-Path $PSScriptRoot 'tools.yaml'),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$StateFile = 'C:\ProgramData\dfir\managed-packages.json'

function Ensure-Prereqs {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        throw "Chocolatey not found. Install FLARE-VM first."
    }
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Install-Module -Name powershell-yaml -Force -Scope CurrentUser -Confirm:$false
    }
    Import-Module powershell-yaml
}

# Returns @{ id = version-or-'latest' } from the manifest.
function Read-Desired($path) {
    $doc = ConvertFrom-Yaml (Get-Content -Raw $path)
    $desired = @{}
    foreach ($p in $doc.packages) { $desired[$p.id] = "$($p.version)" }
    return $desired
}

function Read-State {
    if (Test-Path $StateFile) {
        return (Get-Content -Raw $StateFile | ConvertFrom-Json).psobject.Properties |
            ForEach-Object -Begin { $h = @{} } -Process { $h[$_.Name] = $_.Value } -End { $h }
    }
    return @{}
}

function Write-State($desired) {
    New-Item -ItemType Directory -Force -Path (Split-Path $StateFile) | Out-Null
    $desired | ConvertTo-Json | Set-Content -Encoding UTF8 $StateFile
}

Ensure-Prereqs
$desired = Read-Desired $Manifest
$previous = Read-State

# Prune set: recorded last time, absent now.
$toRemove = $previous.Keys | Where-Object { -not $desired.ContainsKey($_) }

Write-Host "== Reconcile plan ($Manifest) ==" -ForegroundColor Cyan
foreach ($id in $desired.Keys) {
    $v = $desired[$id]
    if ($v -eq 'latest') { Write-Host "  ensure/upgrade  $id (latest)" }
    else                 { Write-Host "  ensure/pin      $id ($v)" }
}
foreach ($id in $toRemove) { Write-Host "  REMOVE          $id" -ForegroundColor Yellow }

if ($DryRun) { Write-Host "(dry run — nothing changed)" -ForegroundColor DarkGray; return }

foreach ($id in $desired.Keys) {
    $v = $desired[$id]
    if ($v -eq 'latest') {
        choco upgrade $id -y --limit-output
    } else {
        choco install $id --version $v -y --allow-downgrade --limit-output
    }
}

foreach ($id in $toRemove) {
    choco uninstall $id -y --remove-dependencies --limit-output
}

Write-State $desired
Write-Host "[+] DFIR environment converged." -ForegroundColor Green
