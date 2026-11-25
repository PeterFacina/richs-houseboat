param(
    [Parameter(Mandatory)][string]$Workspace,
    [Parameter(Mandatory)][string]$Prompts,
    [Parameter(Mandatory)][string]$Output,
    [Parameter(Mandatory)][string]$Case,
    [Parameter(Mandatory)][ValidateSet('original','deterministic-v1')][string]$Mode,
    [Parameter(Mandatory)][string]$Godot
)
$ErrorActionPreference = 'Stop'
$fixtures = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'production-cases.json') | ConvertFrom-Json
if ($Case -notin $fixtures.cases.id) { throw 'Unknown benchmark report.' }
$Workspace = (Resolve-Path -LiteralPath $Workspace).Path
$Godot = (Resolve-Path -LiteralPath $Godot).Path
$Output = (Resolve-Path -LiteralPath $Output).Path
$prefix = "$Case.$Mode"
$appData = Join-Path $Output "houseboat-xp-$prefix"
$events = Join-Path $Output "$prefix.events.jsonl"
$metrics = Join-Path $Output "$prefix.run.json"
if ((Test-Path -LiteralPath $metrics) -or (Test-Path -LiteralPath $events)) { throw 'Choose a fresh output for each trial.' }
if ((git -C $Workspace rev-parse HEAD).Trim() -ne $fixtures.source -or (git -C $Workspace status --porcelain)) {
    throw 'The benchmark worktree must be clean and pinned to the case revision.'
}
$brief = Get-Content -Raw -LiteralPath (Join-Path $Prompts "$prefix.txt")
New-Item -ItemType Directory -Path $appData | Out-Null
$oldAppData = $env:APPDATA
$env:APPDATA = $appData
$instructions = @"
Implement the game report in the supplied brief in this disposable benchmark worktree only. Verify the cause and make a focused change. Use the pre-pinned revision. The benchmark operator has checked active task overlap and GitHub main. Leave other worktrees, live worker state, and real saved games alone. Do not publish, commit, call external services, or use other agents. Run focused checks when possible and report any outstanding acceptance criteria. The Godot 4.7.2 console executable is at $Godot. Use headless tests with this trial's private APPDATA. For interactive playtests, report the remaining checks instead of launching a window.

$brief
"@
$watch = [Diagnostics.Stopwatch]::StartNew()
try {
    $runnerArgs = @('exec','-C',$Workspace,'--ignore-user-config','--ephemeral','--json','--sandbox','workspace-write',
        '-m','gpt-6.2-sol','-c','model_reasoning_effort="medium"','-c','approval_policy="never"','-')
    $instructions | codex @runnerArgs > $events 2> (Join-Path $Output "$prefix.stderr.log")
    $exitCode = $LASTEXITCODE
} finally {
    $watch.Stop()
    $env:APPDATA = $oldAppData
}
$rows = @(Get-Content -LiteralPath $events | Where-Object { $_ } | ConvertFrom-Json)
$turn = $rows | Where-Object type -eq 'turn.completed' | Select-Object -Last 1
$commands = @($rows | Where-Object { $_.type -eq 'item.completed' -and $_.item.type -eq 'command_execution' })
[ordered]@{
    case = $Case
    mode = $Mode
    revision = $fixtures.source
    model = 'gpt-6.2-sol'
    effort = 'medium'
    elapsedSeconds = [Math]::Round($watch.Elapsed.TotalSeconds, 2)
    exitCode = $exitCode
    usage = $turn.usage
    commands = $commands.Count
    files = @(git -C $Workspace status --porcelain)
} | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 -LiteralPath $metrics
Get-Content -LiteralPath $metrics
exit $exitCode
