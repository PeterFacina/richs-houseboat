$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'This automated ETW self-test must run elevated.'
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$output = Join-Path $env:LOCALAPPDATA "RichsHouseboat\trace-self-test\$stamp"
New-Item -ItemType Directory -Force -Path $output | Out-Null
$log = Join-Path $output 'self-test.log'
$etl = Join-Path $output 'pipeline.etl'
$retained = Join-Path $output 'pipeline.etl.trace'
$csv = Join-Path $output 'events.csv'
$result = Join-Path $output 'result.json'

function Invoke-LoggedNative([string]$Label, [scriptblock]$Command) {
    "[$([DateTimeOffset]::Now.ToString('o'))] BEGIN $Label" | Tee-Object -LiteralPath $log -Append
    & $Command 2>&1 | Tee-Object -LiteralPath $log -Append
    $exitCode = $LASTEXITCODE
    "[$([DateTimeOffset]::Now.ToString('o'))] END $Label exit=$exitCode" | Tee-Object -LiteralPath $log -Append
    if ($exitCode -ne 0) { throw "$Label failed with exit code $exitCode" }
}

try {
    $status = (& wpr -status 2>&1 | Out-String)
    $status | Set-Content -LiteralPath $log -Encoding utf8
    if ($status -notmatch 'WPR is not recording') { throw 'Another WPR session is already active.' }

    Invoke-LoggedNative 'wpr-start' { wpr -start CPU -start GPU -start DesktopComposition -filemode }
    Start-Sleep -Seconds 5
    Invoke-LoggedNative 'wpr-marker' { wpr -marker RH_PIPELINE_SELF_TEST }
    Invoke-LoggedNative 'wpr-stop' { wpr -stop $etl 'Automated Richs Houseboat ETW pipeline self-test' }

    if (-not (Test-Path -LiteralPath $etl)) { throw 'WPR returned success but the ETL does not exist.' }
    $before = Get-Item -LiteralPath $etl
    if ($before.Length -lt 4096) { throw "ETL is unexpectedly small: $($before.Length) bytes." }
    $hash = (Get-FileHash -LiteralPath $etl -Algorithm SHA256).Hash
    Move-Item -LiteralPath $etl -Destination $retained -Force
    if (-not (Test-Path -LiteralPath $retained)) { throw 'Neutral-extension retention failed.' }

    Invoke-LoggedNative 'tracerpt-parse' { tracerpt -l $retained -o $csv -of CSV -y }
    if (-not (Test-Path -LiteralPath $retained)) { throw 'Parsing removed the retained trace.' }
    if (-not (Test-Path -LiteralPath $csv)) { throw 'tracerpt returned success without a CSV.' }
    $parsed = Get-Item -LiteralPath $csv
    if ($parsed.Length -lt 128) { throw "Parsed CSV is unexpectedly small: $($parsed.Length) bytes." }

    @{
        passed = $true
        completed = [DateTimeOffset]::Now.ToString('o')
        trace = $retained
        trace_bytes = (Get-Item -LiteralPath $retained).Length
        trace_sha256 = $hash
        parsed_csv = $csv
        parsed_bytes = $parsed.Length
        log = $log
    } | ConvertTo-Json | Set-Content -LiteralPath $result -Encoding utf8
} catch {
    $message = $_.Exception.Message
    "[$([DateTimeOffset]::Now.ToString('o'))] FAIL $message" | Tee-Object -LiteralPath $log -Append
    & wpr -cancel 2>&1 | Tee-Object -LiteralPath $log -Append
    @{ passed = $false; error = $message; log = $log } | ConvertTo-Json |
        Set-Content -LiteralPath $result -Encoding utf8
    exit 1
}
