<#
.SYNOPSIS
  Copy the mods your Modrinth profile has, but the Pi server is missing, to the Pi.

.DESCRIPTION
  Some modpacks ship part of their mods in a way that server installers skip.
  Players then get "Channel ... is missing on the server side". This script:
    1. Lists the .jar files in your Modrinth profile's mods folder.
    2. Lists the server's mods (and mods-disabled, treated as known client-only) over SSH.
    3. Shows what is missing, asks for confirmation, and copies it with scp.

  Run it while the server folder still belongs to your own user (before importing
  into Crafty), and with the server stopped.

.PARAMETER ProfileName
  Name of the Modrinth profile folder, e.g. "Better MC [NEOFORGE] BMC5".

.PARAMETER PiHost
  SSH target, e.g. "pi@pi5.local".

.PARAMETER ServerDir
  Server folder on the Pi, e.g. "/home/pi/minecraft/better-mc-neoforge-bmc5".

.PARAMETER Exclude
  Extra wildcard patterns to never copy (client-only mods), e.g. "BetterGrassify*".

.EXAMPLE
  .\sync-missing-mods.ps1 -ProfileName "Better MC [NEOFORGE] BMC5" -PiHost pi@pi5.local `
      -ServerDir /home/pi/minecraft/better-mc-neoforge-bmc5
#>
param(
  [Parameter(Mandatory = $true)] [string] $ProfileName,
  [Parameter(Mandatory = $true)] [string] $PiHost,
  [Parameter(Mandatory = $true)] [string] $ServerDir,
  [string[]] $Exclude = @()
)

$ErrorActionPreference = 'Stop'

$profileDir = Join-Path $env:APPDATA "ModrinthApp\profiles\$ProfileName"
$modsDir    = Join-Path $profileDir 'mods'
if (-not (Test-Path -LiteralPath $modsDir)) {
  Write-Host "Profile mods folder not found: $modsDir" -ForegroundColor Red
  Write-Host "Profiles available:"
  Get-ChildItem (Join-Path $env:APPDATA 'ModrinthApp\profiles') -Name
  exit 1
}

$clientMods = Get-ChildItem -LiteralPath $modsDir -Filter '*.jar' -File | Select-Object -ExpandProperty Name

Write-Host "Reading the server's mod list over SSH (you may be asked for the Pi password)..."
$remoteCmd = "ls '$ServerDir/mods' '$ServerDir/mods-disabled' 2>/dev/null"
$serverMods = @(& ssh $PiHost $remoteCmd) | Where-Object { $_ -like '*.jar' }
if ($LASTEXITCODE -ne 0 -and $serverMods.Count -eq 0) {
  Write-Host "Could not list $ServerDir/mods on $PiHost." -ForegroundColor Red
  exit 1
}

$missing = $clientMods | Where-Object {
  $name = $_
  ($serverMods -notcontains $name) -and -not ($Exclude | Where-Object { $name -like $_ })
}

if (-not $missing) {
  Write-Host "Nothing to copy: the server already has every mod from your profile." -ForegroundColor Green
  exit 0
}

Write-Host ""
Write-Host "Mods in your profile but not on the server:" -ForegroundColor Yellow
$missing | ForEach-Object { Write-Host "  $_" }
Write-Host ""
Write-Host "Purely visual mods (shaders, grass/leaf looks, menus) may crash the server."
Write-Host "Copy anyway? If one crashes the server, scripts/find-broken-mods.sh parks it in mods-disabled."
$answer = Read-Host "Copy these $($missing.Count) mod(s) to the Pi? [y/N]"
if ($answer -notmatch '^[Yy]$') { Write-Host "Nothing copied."; exit 0 }

$paths = $missing | ForEach-Object { Join-Path $modsDir $_ }
& scp @paths "${PiHost}:$ServerDir/mods/"
if ($LASTEXITCODE -eq 0) {
  Write-Host "Done. Start the server and try to join again." -ForegroundColor Green
} else {
  Write-Host "scp failed (exit code $LASTEXITCODE)." -ForegroundColor Red
}
