$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows_common.ps1')
$studioNode = Find-StudioNode
Push-Location -LiteralPath $PSScriptRoot
try { & $studioNode --test; $studioExit = $LASTEXITCODE }
finally { Pop-Location }
exit $studioExit
