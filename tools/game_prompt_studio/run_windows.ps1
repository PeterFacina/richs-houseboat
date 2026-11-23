param([switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows_common.ps1')
$studioNode = Find-StudioNode
$studioPaths = Get-StudioPaths $studioNode
Start-StudioOllama (Find-StudioOllama) $studioPaths
$studioOrigin = if ($studioPaths.privateOrigin) { $studioPaths.privateOrigin } else { "http://127.0.0.1:$($studioPaths.port)" }
Write-Host "Open $studioOrigin. Press Ctrl+C to stop the studio."
$studioServer = Join-Path $PSScriptRoot 'server.mjs'
if ($NoBrowser -or $studioPaths.privateOrigin) { & $studioNode $studioServer }
else { & $studioNode $studioServer --open-browser }
exit $LASTEXITCODE
