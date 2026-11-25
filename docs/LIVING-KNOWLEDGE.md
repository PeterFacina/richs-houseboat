# Living knowledge

[Game identity](GAME-IDENTITY.md) is the canonical terminology and design reference. The source index and Prompt Studio resolve historical names to current paths during retrieval, while commit-pinned examples retain their original paths.

## Three layers

- Durable knowledge: AGENTS.md, the architecture index and selected subsystem guides. Update these when contracts change, not whenever a PR opens.
- Generated knowledge: a deterministic source inventory, function/signal/class declarations and direct literal Godot resource references, built from tracked files in the current checkout. CI refreshes the index on every push to main and PR targeting main; it publishes a commit-tagged artifact, not a bot commit.
- Live knowledge: current GitHub issues, PRs and diffs. Retrieve them at task start rather than storing stale lists in permanent docs.

## Start a task

Read AGENTS.md first. Run the required read-only bootstrap from the repository root:

```sh
python tools/knowledge/start_task.py "houseboat water drift"
```

It reports local HEAD, branch, whole-worktree dirty status, cached origin/main (not live freshness), guide hints, bounded source matches, and live issue/PR shortlists using REST without gh. It does not fetch, checkout, edit, or publish anything. Network failure returns a failure status and exit code 2; local information is still printed. Use --offline only when necessary and report overlap as unknown. Guide and symbol matches are heuristic; verify actual source and relevant PR patches. Do not pass untrusted issue text as a shell command.

For new edits fetch latest main and create a task worktree; keep existing work untouched when resuming. If bootstrap fails, use authenticated GitHub tools or, where installed, GitHub CLI (run in the repository):

```sh
gh issue list --state open --limit 100 --json number,title,assignees,labels,url
gh pr list --state open --limit 100 --json number,title,isDraft,headRefName,url
gh pr diff NUMBER --name-only
```

Use search/pagination if the list is incomplete or more than 100 items. Read the relevant issue, comments and PR diff as needed. If unavailable, disclose the overlap check limitation. Do not treat a lack of search results as definitive proof of no overlap.

## Targeted source retrieval

From the repo root, with Python 3 and Git available:

```sh
python tools/knowledge/index.py --query "passive_water_velocity"
python tools/knowledge/index.py --query "river_crew pose" --limit 5
python tools/knowledge/index.py --output /path/to/index.json
```

On Windows, substitute a valid output path and use the installed Python launcher if needed. If Python/Git are not available, use the existing [Windows lookup](../tools/godot-lookup/README.md) or targeted source search. The query mode prints only bounded matching paths/symbols and a few direct dependencies. Never load the full index into an agent unless necessary. Read the indicated current source before editing.

The index records HEAD, whether indexed working files differ from HEAD, per-file content hashes, declarations and direct literal res:// references to tracked indexed source. It does not resolve dynamic references, calls, runtime signal connections or all Godot dependencies. Regex matches are hints, not parsed semantic facts. Untracked files are excluded; search them separately if relevant. The existing Graphify snapshot remains optional and independently maintained; this workflow does not regenerate Graphify itself. CI builds against the exact checkout (PR merge preview or main commit), not a continuously moving branch.

## Documentation freshness

CI compares the PR base to the checked-out merge preview (or previous main revision to current main) and flags subsystem guides whose linked files changed but whose guide did not. This is advisory: many changes do not affect a guide and some dependencies are not explicitly linked. Review the summary and update the guide when necessary. No AI calls, secrets, automatic merges or documentation rewrites are required.

## Prompt Studio

The [GPU worker knowledge integration](GPU-WORKER-KNOWLEDGE.md) uses the same deterministic indexer against a dedicated sparse checkout of `main`. Prompt Studio retrieves bounded excerpts using the index, selected guides, and related live GitHub tasks. The worker records the pinned source commit for each generation. Check the deployed worker revision separately from the game revision shown in its briefs. The CI artifact remains available for development and review.

## Verification and metrics

Run `python -m unittest discover -s tools/knowledge -p "test_*.py"`. Compare identical tasks with and without targeted retrieval, recording actual input/output tokens, context bytes, acceptance rounds and regressions. See [retrieval benchmark](RETRIEVAL-BENCHMARK.md) for exploratory measurements and the controlled test protocol.

## Bounded function and GitHub retrieval

From the repository root:

```sh
python tools/knowledge/retrieve.py passive_water_velocity --lines 60 --budget 8000
python tools/knowledge/retrieve.py sail_river --path godot-cove/houseboat.gd
python tools/knowledge/github_context.py --query "boat drift helm"
python tools/knowledge/github_context.py --pr NUMBER
python tools/knowledge/github_context.py --pr NUMBER --path godot-cove/houseboat.gd
```

Replace NUMBER with the actual PR number. The local tool returns exact-name GDScript function excerpts and lexical call-site hints, including enclosing function where recognizable. It uses indentation heuristics, not a parser; strings, multiline syntax, inherited methods, dynamic dispatch and comments can affect results. Verify callers, ownership and omitted ranges in current source. Partial/truncated output is explicitly marked. The byte budget is not a token budget. Continue with targeted reads if a definition or relevant caller is omitted. Use the existing index for direct literal resource references.

The GitHub tool uses public read-only REST endpoints, optionally with existing GH_TOKEN/GITHUB_TOKEN in the environment. It does not print credentials. It filters title/body/labels locally and returns compact metadata; keyword matching can miss related work. PR file lists are compact by default; exact path selection returns available patch text subject to budget. GitHub patches may be incomplete or omitted; inspect the actual diff if needed. Network/rate/pagination errors are failures, not proof that no work exists. Do not send untrusted issue text to shell commands.
