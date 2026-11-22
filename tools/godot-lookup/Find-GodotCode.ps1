param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Query,
    [string]$Project,
    [ValidateRange(1, 8)][int]$Limit = 3,
    [ValidateRange(60, 400)][int]$Budget = 150,
    [switch]$Trace
)
$ErrorActionPreference = 'Stop'
if (!$Project) { $Project = Join-Path $PSScriptRoot '../../godot-cove' }
$root = (Resolve-Path -LiteralPath $Project).Path
if (-not (Test-Path -LiteralPath (Join-Path $root 'project.godot'))) {
    throw 'Pass the folder containing project.godot as -Project.'
}
$terms = @([regex]::Matches($Query.ToLowerInvariant(), '[a-z0-9]+') |
    ForEach-Object { $_.Value } | Where-Object { $_.Length -gt 2 } | Sort-Object -Unique)
if (!$terms.Count) { throw 'Use two or three specific source keywords.' }
$termPatterns = @($terms | ForEach-Object { '(?<![a-z0-9])' + [regex]::Escape($_) })
$pattern = $termPatterns -join '|'

$files = New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'
$dirs = New-Object 'System.Collections.Generic.Stack[string]'
$dirs.Push($root)
while ($dirs.Count) {
    foreach ($entry in Get-ChildItem -LiteralPath $dirs.Pop()) {
        if ($entry.Name.StartsWith('.') -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
        if ($entry.PSIsContainer) { $dirs.Push($entry.FullName) }
        elseif ($entry.Extension -in '.gd','.tscn','.tres','.gdshader','.cs' -or $entry.Name -eq 'project.godot') {
            $files.Add($entry)
        }
    }
}

$hits = foreach ($file in $files) {
    $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
    $nameHits = @($termPatterns | Where-Object { $file.BaseName -match $_ }).Count
    $symbol = ''
    $lineNumber = 0
    $best = $null
    foreach ($line in [IO.File]::ReadLines($file.FullName)) {
        $lineNumber++
        if ($line -match '^\s*(?:static\s+)?func\s+(\w+)') { $symbol = $Matches[1] + '()' }
        if ($line -notmatch $pattern) { continue }
        $matched = @($termPatterns | Where-Object { $line -match $_ })
        $score = 4 * $nameHits + 3 * $matched.Count
        if ($symbol -and ($line -match '^\s*(?:static\s+)?func\s')) { $score++ }
        if ($line -match '^\s*#') { $score-- }
        if (!$best -or $score -gt $best.Score) {
            $best = [pscustomobject]@{ Path = $relative; Full = $file.FullName; Line = $lineNumber
                Symbol = $symbol; Text = $line.Trim(); Score = $score }
        }
    }
    if ($best) { $best }
    elseif ($nameHits) {
        [pscustomobject]@{ Path = $relative; Full = $file.FullName; Line = 1
            Symbol = ''; Text = ''; Score = 4 * $nameHits }
    }
}

$ranked = @($hits | Sort-Object @{Expression='Score';Descending=$true}, Path | Select-Object -First $Limit)
$remaining = 3 * $Budget
function Write-Budgeted([string]$line) {
    $cost = [Text.Encoding]::UTF8.GetByteCount($line) + 2
    if ($cost -le $script:remaining) {
        $script:remaining -= $cost
        $line
    }
}
foreach ($hit in $ranked) {
    $label = '{0}:{1} {2}' -f $hit.Path, $hit.Line, $hit.Symbol
    $text = $hit.Text
    if ($text.Length -gt 96) { $text = $text.Substring(0, 93) + '...' }
    if ($text) { $label = "$($label.TrimEnd()) | $text" }
    Write-Budgeted $label.TrimEnd()
}
if (!$ranked.Count) { Write-Budgeted 'No matches. Try a filename or a symbol from the task.' }

function Get-SourceHash([string]$path) {
    $stream = [IO.File]::OpenRead($path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

if ($Trace -and $ranked.Count) {
    $indexPath = Join-Path $PSScriptRoot 'links.json'
    if (!(Test-Path -LiteralPath $indexPath)) { return }
    $index = Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json
    $fresh = @{}
    $shown = 0
    $neighbors = $index.links |
        Where-Object { $_.from -eq $ranked[0].Path -or $_.to -eq $ranked[0].Path } |
        Sort-Object @{Expression={ $_.from -in $ranked.Path -and $_.to -in $ranked.Path };Descending=$true}
    foreach ($edge in $neighbors) {
        foreach ($name in @($edge.from, $edge.to)) {
            if ($fresh.ContainsKey($name)) { continue }
            $full = [IO.Path]::GetFullPath((Join-Path $root $name))
            $hash = $index.hashes.PSObject.Properties[$name]
            $fresh[$name] = $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase) -and $hash -and
                (Test-Path -LiteralPath $full -PathType Leaf) -and
                ((Get-SourceHash $full) -eq $hash.Value)
        }
        if ($fresh[$edge.from] -and $fresh[$edge.to]) {
            $link = Write-Budgeted ('{0} --{1}--> {2}' -f $edge.from, $edge.relation, $edge.to)
            if ($link) { $link; $shown++ }
            if ($shown -ge 2) { break }
        }
    }
}
