param(
    [ValidateSet('compatibility', 'mobile', 'forward_plus')]
    [string]$Renderer = 'compatibility',
    [ValidateSet('windowed', 'fullscreen', 'exclusive')]
    [string]$WindowMode = 'windowed',
    [string]$OutputDirectory = 'benchmark-results'
)

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $taskRoot 'godot-cove'
$candidateExecutables = @(
    (Join-Path $taskRoot 'build\godot\Godot_v4.7.2-stable_win64_console.exe'),
    (Join-Path (Split-Path -Parent $taskRoot) 'Deep River GMod Game\build\godot\Godot_v4.7.2-stable_win64_console.exe')
)
$godotExecutable = $candidateExecutables | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $godotExecutable) {
    throw 'Godot 4.7.2 console executable was not found in the task or main workspace build/godot directory.'
}

$resolvedOutput = Join-Path $taskRoot $OutputDirectory
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$resultPath = Join-Path $resolvedOutput "render-$Renderer-$WindowMode-$stamp.txt"

$rendererArguments = switch ($Renderer) {
    'compatibility' { @('--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3') }
    'mobile' { @('--rendering-method', 'mobile', '--rendering-driver', 'vulkan') }
    'forward_plus' { @('--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan') }
}
$godotArguments = @('--path', $projectPath) + $rendererArguments + @(
    '--script', 'res://tests/profile_world_runtime.gd', '--', '--monitorless',
    "--window-mode=$WindowMode", '--trace-only'
)

"Rich's Houseboat rendering benchmark" | Set-Content -LiteralPath $resultPath
"Timestamp: $(Get-Date -Format o)" | Add-Content -LiteralPath $resultPath
"Renderer: $Renderer" | Add-Content -LiteralPath $resultPath
"Window mode: $WindowMode" | Add-Content -LiteralPath $resultPath
"Godot: $godotExecutable" | Add-Content -LiteralPath $resultPath
"OS: $([System.Environment]::OSVersion.VersionString)" | Add-Content -LiteralPath $resultPath
"CPU: $((Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty Name).Trim())" | Add-Content -LiteralPath $resultPath
"Memory bytes: $((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory)" | Add-Content -LiteralPath $resultPath
"Displays: $((Get-CimInstance Win32_DesktopMonitor | Where-Object Status -eq 'OK').Count)" | Add-Content -LiteralPath $resultPath
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    'NVIDIA:' | Add-Content -LiteralPath $resultPath
    (& nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>&1) | Add-Content -LiteralPath $resultPath
}
'--- Godot output ---' | Add-Content -LiteralPath $resultPath
& $godotExecutable @godotArguments 2>&1 | Tee-Object -Variable godotOutput
$godotOutput | Add-Content -LiteralPath $resultPath
Write-Host "Benchmark saved to $resultPath"
