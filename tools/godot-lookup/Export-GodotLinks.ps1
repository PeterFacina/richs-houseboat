param([Parameter(Mandatory = $true)][string]$Snapshot)
$ErrorActionPreference = 'Stop'
$graph = Get-Content -LiteralPath (Join-Path $Snapshot 'graph.json') -Raw | ConvertFrom-Json
$coverage = Get-Content -LiteralPath (Join-Path $Snapshot 'coverage.json') -Raw | ConvertFrom-Json
$nodes = @{}
$hashes = [ordered]@{}
foreach ($node in $graph.nodes) { $nodes[$node.id] = $node.source_file }
$edges = foreach ($edge in $graph.links) {
    if ($edge.confidence -ne 'EXTRACTED' -or
        $edge.relation -notin 'attaches_script','instances','imports_from','runs_main_scene') { continue }
    $from = $nodes[$edge._src]
    $to = $nodes[$edge._tgt]
    if (!$from -or !$to -or $from -eq $to) { continue }
    foreach ($name in @($from, $to)) {
        $hash = $coverage.sha256_before_and_after.PSObject.Properties[$name]
        if ($hash) { $hashes[$name] = $hash.Value }
    }
    [pscustomobject]@{from=$from; to=$to; relation=$edge.relation}
}
$links = @($edges | Sort-Object from,to,relation -Unique)
@{hashes=$hashes; links=$links} | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $PSScriptRoot 'links.json') -Encoding UTF8
