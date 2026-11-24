function Find-StudioNode {
    $studioCommand = Get-Command node.exe -ErrorAction SilentlyContinue
    if (!$studioCommand) { throw 'Install Node.js 24 LTS and reopen PowerShell.' }
    & $studioCommand.Source -e "if (+process.versions.node.split('.')[0] < 24) process.exit(1)"
    if ($LASTEXITCODE -ne 0) { throw 'Game Prompt Studio requires Node.js 24 or later.' }
    return $studioCommand.Source
}
function Get-StudioPaths([string]$NodeExe) {
    $studioResult = & $NodeExe (Join-Path $PSScriptRoot 'control.mjs') paths
    if ($LASTEXITCODE -ne 0) { throw 'Read the studio configuration error above.' }
    return $studioResult | ConvertFrom-Json
}
function Find-StudioOllama {
    $studioCommand = Get-Command ollama.exe -ErrorAction SilentlyContinue
    if ($studioCommand) { return $studioCommand.Source }
    foreach ($studioPath in @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'),
        (Join-Path $env:ProgramFiles 'Ollama\ollama.exe')
    )) {
        if (Test-Path -LiteralPath $studioPath -PathType Leaf) { return $studioPath }
    }
    $studioPortable = Join-Path $env:LOCALAPPDATA 'GamePromptStudio'
    if (Test-Path -LiteralPath $studioPortable) {
        $studioBuild = Get-ChildItem -LiteralPath $studioPortable -Directory -Filter 'ollama-v*' |
            Sort-Object LastWriteTime -Descending | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'ollama.exe') } |
            Select-Object -First 1
        if ($studioBuild) { return (Join-Path $studioBuild.FullName 'ollama.exe') }
    }
    return $null
}
function Test-StudioOllama([int]$Port) {
    try {
        $studioService = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/api/version" -TimeoutSec 2
        return [bool]$studioService.version
    } catch { return $false }
}
function Start-StudioOllama([string]$OllamaExe, $Paths) {
    $studioPort = [int]$Paths.ollamaPort
    if (Test-StudioOllama $studioPort) { return }
    if (!$OllamaExe) {
        Write-Host 'Ollama is offline. Install Ollama or start the existing service. The studio library is still available.'
        return
    }
    $studioRuntime = Join-Path $env:LOCALAPPDATA 'GamePromptStudio'
    New-Item -ItemType Directory -Path $studioRuntime -Force | Out-Null
    $env:OLLAMA_HOST = "127.0.0.1:$studioPort"
    $env:OLLAMA_NO_CLOUD = '1'
    $env:OLLAMA_NUM_PARALLEL = '1'
    Start-Process -FilePath $OllamaExe -ArgumentList 'serve' -WindowStyle Hidden -RedirectStandardOutput (Join-Path $studioRuntime 'ollama.log') -RedirectStandardError (Join-Path $studioRuntime 'ollama.errors.log')
    for ($studioAttempt = 0; $studioAttempt -lt 10; $studioAttempt++) {
        if (Test-StudioOllama $studioPort) { return }
        Start-Sleep -Milliseconds 300
    }
    Write-Host "Ollama did not start on port $studioPort. Check its log in $studioRuntime."
}
