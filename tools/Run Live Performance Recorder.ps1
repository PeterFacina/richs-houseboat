param(
    [ValidateSet('compatibility', 'mobile')]
    [string]$Renderer = 'compatibility'
)

$taskRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $taskRoot 'godot-cove'
$workspaceParent = Split-Path -Parent (Split-Path -Parent $taskRoot)
$engineCandidates = @(
    (Join-Path $taskRoot 'build\godot\Godot_v4.7.2-stable_win64.exe'),
    (Join-Path $workspaceParent 'Deep River GMod Game\build\godot\Godot_v4.7.2-stable_win64.exe')
)
$engine = $engineCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $engine) {
    throw 'Godot 4.7.2 executable was not found in the task or main workspace build/godot directory.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$output = Join-Path $taskRoot "benchmark-results\live-$stamp"
New-Item -ItemType Directory -Force -Path $output | Out-Null
$rendererArguments = if ($Renderer -eq 'mobile') {
    @('--rendering-method', 'mobile', '--rendering-driver', 'vulkan')
} else {
    @('--rendering-method', 'gl_compatibility')
}
$arguments = @('--path', $projectPath) + $rendererArguments + @(
    '--', '--live-performance-recorder', "--performance-output=$output"
)
$game = Start-Process -FilePath $engine -ArgumentList (($arguments | ForEach-Object {
    if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
}) -join ' ') -PassThru

$systemCsv = Join-Path $output 'system-samples.csv'
'unix_ms,process_cpu_ms,working_set_bytes,private_bytes,io_read_bytes,io_write_bytes,system_cpu_percent,disk_bytes_per_sec' |
    Set-Content -LiteralPath $systemCsv -Encoding utf8
$previousCpu = 0.0
$previousAt = [DateTimeOffset]::UtcNow
$game.Refresh()
$previousCpu = $game.TotalProcessorTime.TotalMilliseconds
while (-not $game.HasExited) {
    Start-Sleep -Milliseconds 500
    $game.Refresh()
    if ($game.HasExited) { break }
    $now = [DateTimeOffset]::UtcNow
    $cpuMs = $game.TotalProcessorTime.TotalMilliseconds
    $elapsedMs = [Math]::Max(1.0, ($now - $previousAt).TotalMilliseconds)
    $cpuPercent = (($cpuMs - $previousCpu) / $elapsedMs) * 100.0 / [Environment]::ProcessorCount
    $previousCpu = $cpuMs
    $previousAt = $now
    $ioRead = 0
    $ioWrite = 0
    try {
        $io = Get-CimInstance Win32_Process -Filter "ProcessId = $($game.Id)" -Property ReadTransferCount,WriteTransferCount
        if ($io) {
            $ioRead = $io.ReadTransferCount
            $ioWrite = $io.WriteTransferCount
        }
    } catch {}
    $diskRate = 0.0
    try {
        $diskRate = (Get-Counter '\PhysicalDisk(_Total)\Disk Bytes/sec' -ErrorAction Stop).CounterSamples[0].CookedValue
    } catch {}
    '{0},{1:F3},{2},{3},{4},{5},{6:F3},{7:F3}' -f $now.ToUnixTimeMilliseconds(), $cpuMs,
        $game.WorkingSet64, $game.PrivateMemorySize64, $ioRead, $ioWrite, $cpuPercent, $diskRate |
        Add-Content -LiteralPath $systemCsv -Encoding utf8
}

Write-Host "Recorder output: $output"
