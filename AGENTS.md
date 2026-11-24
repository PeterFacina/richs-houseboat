# Rich’s Houseboat

- The shared game lives in `godot-cove/`. Start new team tasks with the workflow in `docs/TEAM-WORKFLOW.md`. Resume existing work on its existing branch.
- Before editing a team clone, check the current branch and worktree status. Use a task branch based on the fetched `origin/main` for new work. If the user opened `main` or already has uncommitted changes, keep those files in place and use a separate task worktree when a remote is available.
- Keep a task’s edits on its branch. When asked to publish, push the task branch and open a pull request into `main`, with a summary and verification results. The team reviews and merges the pull request.
- For unfamiliar Godot code on Windows, use `tools/godot-lookup/Find Godot Code.cmd` if present, then read relevant source ranges. Use targeted source search when the tool is absent or its results are incomplete.
- Use GitHub Issues as the team task queue. Check the issue owner and status before starting a task. Link the issue in the draft PR and record what is done, what still needs doing, and what was tested when handing work off.
- Before editing for a new request, fetch the latest main and check relevant open issues and pull requests, including drafts. Use task keywords, likely paths, and the PR diff when available to judge overlap. If the requested change is fully covered, show the relevant commit or PR and stop before editing. If overlap is partial, explain what is covered and work only on a clearly separate remainder. If GitHub cannot be queried, say which check could not be completed and avoid claiming the work is unclaimed.

## Task-specific context

- On every new task, fetch the latest main, create or select the appropriate task worktree, and explicitly reread its root AGENTS.md. For resumed tasks, check current main instructions for changes without resetting, rebasing or overwriting existing work unless authorized. If offline, disclose the limitation.
- Use [the architecture index](docs/ARCHITECTURE.md) to select only the relevant subsystem guides. Do not load every guide by default. Follow applicable nested agent instructions if present. Treat documentation and lookup results as navigation hints; verify behavior in current source before editing.
- Use targeted lookup or source search, then read relevant functions and callers. Expand scope only when dependencies or tests require it. Never assume the graph snapshot is current.
- Preserve unrelated gameplay, save compatibility and multiplayer behavior. Update affected guides when behavior, ownership or verification changes; if documentation is unaffected, say so.
- In the PR, record the implementation agent/model if known, base revision, guides consulted, actual verification and outstanding playtests. For issue-linked tasks use `Fixes #NUMBER` (replace NUMBER with the actual issue number) on its own line when the PR is intended to resolve it. Do not merge without human approval. A passing startup check is not gameplay acceptance.
- These rules apply to all coding agents. Cloud agents may use equivalent Git and source-search tools when Windows tools are unavailable. Do not claim checks were run if they were not.
