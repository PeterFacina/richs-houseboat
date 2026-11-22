param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9-]{0,39}$')]
    [string]$Developer,
    [Parameter(Mandatory = $true, Position = 1)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9-]{0,49}$')]
    [string]$Task
)

$ErrorActionPreference = 'Stop'
function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "Git failed: $($args -join ' ')" }
}

$repo = Invoke-Git -C $PSScriptRoot rev-parse --show-toplevel
$branch = "$Developer/$Task".ToLowerInvariant()
$parent = Split-Path -Parent $repo
$name = Split-Path -Leaf $repo
$destination = Join-Path $parent "$name-tasks/$($branch.Replace('/', '-'))"
if (Test-Path -LiteralPath $destination) {
    throw "Task folder already exists. Open it in Codex to resume: $destination"
}
Invoke-Git -C $repo fetch origin refs/heads/main:refs/remotes/origin/main
$base = Invoke-Git -C $repo rev-parse refs/remotes/origin/main
Invoke-Git -C $repo worktree add -b $branch $destination $base
Write-Host "Open this folder in Codex: $destination"
Write-Host "Task branch: $branch"
