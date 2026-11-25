# Rich’s Houseboat

Rich’s Houseboat is a multiplayer open-world life simulation built in Godot and set in Deep River, Ontario, along the Ottawa River. Use [Game identity](docs/GAME-IDENTITY.md) for terminology, narrative direction and compatibility contracts.

## Required task startup (including read-only investigations)

1. Explicitly read this current root AGENTS.md before investigating. Do not assume previously loaded instructions are current. Check the task checkout and applicable nested instructions. For new edits fetch latest main and use a separate task worktree as described below; never silently switch/reset a read-only or existing task checkout.
2. Before broad source discovery, run `python tools/knowledge/start_task.py "short task keywords"` from the repository root. This is read-only and works without gh. It reports local revision, guide hints, symbol matches and live GitHub issues/PRs. It does not fetch or switch branches. For read-only tasks check whether the requested revision is current (fetch or equivalent remote check when relevant); report if not.
3. Read the architecture index and suggested relevant guides, then use `python tools/knowledge/retrieve.py EXACT_FUNCTION` for known functions and the source index for unknown symbols before broad file reads. Inspect relevant issue/PR details and targeted patches with `github_context.py --pr NUMBER` and `--path PATH` or equivalent. A git log is not a live issue/PR check. No gh installation is required by the Python tools.
4. If a required tool fails or its results are insufficient, record the actual failure or gap and use a targeted equivalent. Do not skip a command based on an assumption about its dependencies. Cloud agents without a shell may use equivalent GitHub/source tools and report that substitution. Broaden reads when correctness requires it.
5. In every task report, include a short startup receipt: AGENTS read, bootstrap executed or actual fallback, revision, live overlap status, retrieval tools used and remaining verification gaps. Never claim a check was completed when it was not.

These are required workflow steps, not optional suggestions. They do not override user authorization, safety, or read-only scope.

- The shared game lives in `godot-cove/`. Start new team tasks with the workflow in `docs/TEAM-WORKFLOW.md`. Resume existing work on its existing branch.
- Before editing a team clone, check the current branch and worktree status. Use a task branch based on the fetched `origin/main` for new work. If the user opened `main` or already has uncommitted changes, keep those files in place and use a separate task worktree when a remote is available.
- Keep a task’s edits on its branch. When asked to publish, push the task branch and open a pull request into `main`, with a summary and verification results. The team reviews and merges the pull request.
- As a fallback for unfamiliar Godot code on Windows, use `tools/godot-lookup/Find Godot Code.cmd` if present, then read relevant source ranges. Use targeted source search when the tool is absent or its results are incomplete.
- Use GitHub Issues as the team task queue. Check the issue owner and status before starting a task. Link the issue in the draft PR and record what is done, what still needs doing, and what was tested when handing work off.
- Before editing for a new request, fetch the latest main and check relevant open issues and pull requests, including drafts. Use task keywords, likely paths, and the PR diff when available to judge overlap. If the requested change is fully covered, show the relevant commit or PR and stop before editing. If overlap is partial, explain what is covered and work only on a clearly separate remainder. If GitHub cannot be queried, say which check could not be completed and avoid claiming the work is unclaimed.

## Task-specific context

- On every new editing task, fetch the latest main, create or select the appropriate task worktree, and explicitly reread its root AGENTS.md. For resumed tasks, check current main instructions for changes without resetting, rebasing or overwriting existing work unless authorized. If offline, disclose the limitation.
- Use [the architecture index](docs/ARCHITECTURE.md) to select only the relevant subsystem guides. Do not load every guide by default. Follow applicable nested agent instructions if present. Treat documentation and lookup results as navigation hints; verify behavior in current source before editing.
- Use targeted lookup or source search, then read relevant functions and callers. Expand scope only when dependencies or tests require it. Never assume the graph snapshot is current.
- Preserve unrelated gameplay, save compatibility and multiplayer behavior. Update affected guides when behavior, ownership or verification changes; if documentation is unaffected, say so.
- For a player-facing PR, add one godot-cove/release-notes/pr-<PR number>.json file with pr, player_facing: true, and simple player-facing bullets totaling under 450 characters. After opening the PR, add or rename the file using its assigned PR number and push the update. Keep each PR's notes in its own file so parallel branches do not edit a shared changelog. Infrastructure-only PRs must not add a release note. The game selects the highest numbered player-facing release note for offline main builds, displays that version on the title and pause menus, and shows the latest note on every launch with a repeatable What’s New button.
- The `Release notes / Validate player-facing release note` PR check enforces that rule for runtime changes under `godot-cove/` and validates the JSON fields, file name and PR number. It excludes Markdown/text documentation, internal tools, test folders and the Godot cache. After its first successful run, configure this exact check as a required status check in the repository’s branch protection or ruleset for `main`. The offline What's New popup shows all player-facing PR notes in PR-number order so an older-numbered PR merged later remains visible; title and pause menus continue to use the highest PR number as their version label.
- In the PR, record the implementation agent/model if known, base revision, guides consulted, actual verification and outstanding playtests. For issue-linked tasks use `Fixes #NUMBER` (replace NUMBER with the actual issue number) on its own line when the PR is intended to resolve it. Do not merge without human approval. A passing startup check is not gameplay acceptance.
- These rules apply to all coding agents. Cloud agents may use equivalent Git and source-search tools when Windows tools are unavailable. Do not claim checks were run if they were not.

## Living knowledge

- At task start query current GitHub issues and PRs (including drafts); never rely on issue numbers or open/closed status copied into guides. Check relevant PR diffs for overlap. See [living knowledge](docs/LIVING-KNOWLEDGE.md) for portable commands and offline fallback.
- Use the on-demand source index to find symbols and direct resource dependencies when helpful; it reads the task checkout, not a remote snapshot. Do not put the full generated index in model context. On main, CI produces a fresh commit-tagged index; it is a navigation aid, not an automatic synchronization mechanism.
- Review any documentation freshness advisory on your PR. Update affected guides or explain why the change does not alter their documented contract. Never invent facts to satisfy a check.

## Progressive retrieval and reporting

- For unfamiliar code, use bounded lookup before broad reads. Prefer the exact-function tool in [Living knowledge](docs/LIVING-KNOWLEDGE.md) when a symbol is known; use lexical caller hints and verify actual wiring. Begin with one relevant function or about 60–100 lines, not whole large files. Expand when needed for correctness, with a brief reason. Do not repeat unchanged reads.
- Prefer compact live issue/PR summaries and changed-file lists; inspect relevant diff sections before concluding overlap. A title or keyword match alone is not proof. Use full diffs only when justified. If a tool is unavailable or output truncated, use targeted fallback and disclose gaps.
- Record actual verification, implementation results, limitations, deployment status and actionable follow-ups in the PR or linked GitHub documentation/issues, not only chat. Do not publish secrets, private training records or unsanitized logs.
