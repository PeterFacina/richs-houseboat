# Game Prompt Studio Graphify benchmark

Run this on Ethan's GPU PC from a clean, separate worktree at the draft PR head. Keep the PR in draft. Use Node.js 24, Python 3.12, and the existing Ollama server on loopback with `qwen3:14b`. No Discord credentials or changes to the live Studio instance are needed.

## Build the graph and run both modes

Run from the worktree root in PowerShell. Use a fresh temporary directory for the dependencies and graph.

```powershell
$bench = Join-Path $env:TEMP ("houseboat-graph-" + [guid]::NewGuid())
New-Item -ItemType Directory $bench | Out-Null
git clone https://github.com/hidalgob/graphify-godot.git "$bench/upstream"
git -C "$bench/upstream" checkout --detach cd3d27cc5b201e1135dbc8d62db0704e4040b66b
py -3.12 -m venv "$bench/venv"
$python = "$bench/venv/Scripts/python.exe"
& $python -m pip install "$bench/upstream" "tree-sitter-language-pack==0.13.0"
& $python tools/graphify-studio-benchmark/build_snapshot.py godot-cove "$bench/snapshot"
node tools/graphify-studio-benchmark/benchmark.mjs $python "$bench/snapshot" |
  Set-Content -Encoding utf8 "$bench/results.json"
ollama ps
```

Stop if checkout, dependency installation or graph build fails. The benchmark runs the same three reports using Studio alone and with the top two Graphify file hints. It uses a fresh Studio database per run to keep earlier briefs out of the model context. The two modes use the same report text, game commit, Qwen model, 8K context, and Detailed preset. Each run records the source excerpts sent to the model, guarded export, elapsed time, and real brief when generation succeeds. A nonzero exit can include partial results in the JSON. To verify retrieval without Ollama, add `--retrieval-only` to the Node command.

## Post results on this PR

Post one comment with the tested commit, GPU, Ollama version, `ollama ps` processor, and graph size from the builder output. For each report compare the selected paths and line numbers, elapsed times, export results, and the usefulness of the resulting briefs. Include the six exported briefs in collapsible sections. If the comment would exceed GitHub's limit, post the comparison first, then reply with the briefs in smaller comments.

- **Zero Turn** looks for steering-lever or hand-placement code in `lawn_mower.gd` and preserves that guest visibility is unverified.
- **Fishing rod** checks whether the brief addresses both rod visibility and host/guest behavior using relevant code.
- **Shoreline** checks whether the brief includes a useful `ottawa_map.gd` excerpt for the reported gap.

Flag irrelevant sources, lost details, or invented findings. On failure include the exact error and last successful step. Leave credentials and machine-specific paths out of the comment. Keep this to benchmarking without game changes or fine-tuning.

For the function-ranking follow-up, compare against the results in PR #26. In both fishing runs, inspect the actual excerpts in the JSON for the rod flag in `river_crew.gd` and the `show_rod` / `rod.visible` gate in `crew_avatar.gd`. Check whether the model uses that evidence and proposes a host/guest verification. For the mower and shoreline, call out any useful evidence the new ranking drops. Record the commits on both sides since the game checkout may have changed since PR #26.
