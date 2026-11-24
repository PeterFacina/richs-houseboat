# Living knowledge

## Three layers

- Durable knowledge: AGENTS.md, the architecture index and selected subsystem guides. Update these when contracts change, not whenever a PR opens.
- Generated knowledge: a deterministic source inventory, function/signal/class declarations and direct literal Godot resource references, built from tracked files in the current checkout. CI refreshes the index on every push to main and PR targeting main; it publishes a commit-tagged artifact, not a bot commit.
- Live knowledge: current GitHub issues, PRs and diffs. Retrieve them at task start rather than storing stale lists in permanent docs.

## Start a task

Follow AGENTS.md and the team workflow. Fetch latest main and create a task worktree for new work; keep existing work untouched when resuming. Use authenticated GitHub tools or, where installed, GitHub CLI (run in the repository):

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

The local GPU worker has its own source indexing and provenance. This CI artifact does not automatically update Ethan's checkout or change worker retrieval. Confirm the deployed revision and refresh procedure with the operator; do not hot-update a running worker or mix source revisions within training records.

## Verification and metrics

Run `python -m unittest discover -s tools/knowledge -p "test_*.py"`. Compare identical tasks with and without targeted retrieval, recording actual input/output tokens, context bytes, acceptance rounds and regressions. There is no measured token saving yet.
