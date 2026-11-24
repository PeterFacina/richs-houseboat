param([switch]$PullModel, [string]$Model = 'qwen3:14b')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows_common.ps1')
$studioNode = Find-StudioNode
$studioPaths = Get-StudioPaths $studioNode
if (!(Test-Path -LiteralPath $studioPaths.configPath)) {
    New-Item -ItemType Directory -Path $studioPaths.dataDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'config.example.json') -Destination $studioPaths.configPath
}
$studioIndex = & $studioNode (Join-Path $PSScriptRoot 'control.mjs') init | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the local studio.' }
Write-Host "Indexed $($studioIndex.indexed) project files. Local data is in $($studioPaths.dataDir)."
$studioNvidia = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
if ($studioNvidia) { & $studioNvidia.Source --query-gpu=name,driver_version,memory.total,memory.free --format=csv }
$studioOllama = Find-StudioOllama
if ($studioOllama -and $PullModel) {
    if ($Model -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,64}:[a-zA-Z0-9][a-zA-Z0-9_.-]{0,64}$' -or $Model -match 'cloud|remote') {
        throw 'Choose a tagged local model.'
    }
    Start-StudioOllama $studioOllama $studioPaths
    if (!(Test-StudioOllama $studioPaths.ollamaPort)) { throw 'Start Ollama before pulling a model.' }
    $env:OLLAMA_HOST = "127.0.0.1:$($studioPaths.ollamaPort)"
    & $studioOllama pull $Model
    if ($LASTEXITCODE -ne 0) { throw "Ollama could not pull $Model." }
} elseif (!$studioOllama) {
    Write-Host 'Install Ollama for Windows from https://ollama.com/download/windows, then rerun with -PullModel.'
} else {
    Write-Host 'Ollama found. Run this script with -PullModel if qwen3:14b is missing.'
}
Write-Host 'Launch from this folder with .\run_windows.ps1.'
