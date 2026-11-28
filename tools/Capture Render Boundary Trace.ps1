param([string]$OutputDirectory = '')

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell (Run as administrator).'
}

$taskRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputDirectory = Join-Path $env:LOCALAPPDATA "RichsHouseboat\traces\etl-$stamp"
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$tracePath = Join-Path $OutputDirectory 'render-boundary.etl'
$markerPath = Join-Path $OutputDirectory 'markers.csv'
'marker,local_time,unix_ms' | Set-Content -LiteralPath $markerPath -Encoding utf8

$status = (& wpr -status 2>&1 | Out-String)
if ($status -notmatch 'WPR is not recording') {
    throw "Another WPR recording appears active. Stop or cancel it first.`n$status"
}

Write-Host 'Starting CPU, GPU, and Desktop Composition ETW profiles...'
& wpr -start CPU -start GPU -start DesktopComposition -filemode
if ($LASTEXITCODE -ne 0) {
    throw "WPR failed with exit code $LASTEXITCODE. Confirm this shell is elevated and SeSystemProfilePrivilege is available."
}

$marker = 0
try {
    Write-Host ''
    Write-Host 'Trace is active. Keep this capture under 60 seconds.'
    Write-Host 'In the game, press F9 immediately after a stutter.'
    Write-Host 'Then return here: press ENTER to add the matching ETW marker, or type STOP to finish.'
    while ($true) {
        $answer = Read-Host
        if ($answer -match '^(stop|s)$') { break }
        $marker++
        $name = "RH_STUTTER_$marker"
        & wpr -marker $name
        $now = [DateTimeOffset]::Now
        '{0},{1},{2}' -f $name, $now.ToString('o'), $now.ToUnixTimeMilliseconds() |
            Add-Content -LiteralPath $markerPath -Encoding utf8
        Write-Host "Marked $name. Press ENTER after another F9 incident, or type STOP."
    }
    & wpr -stop $tracePath 'Richs Houseboat rendering-boundary gameplay stalls'
    if ($LASTEXITCODE -ne 0) { throw "WPR stop failed with exit code $LASTEXITCODE." }
    Write-Host "Trace: $tracePath"
    Write-Host "Markers: $markerPath"
} catch {
    & wpr -cancel | Out-Null
    throw
}
