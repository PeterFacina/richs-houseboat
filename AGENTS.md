# Rich’s Houseboat

- The shared game lives in `godot-cove/`. Start new team tasks with the workflow in `docs/TEAM-WORKFLOW.md`. Resume existing work on its existing branch.
- Before editing a team clone, check the current branch and worktree status. Use a task branch based on the fetched `origin/main` for new work. If the user opened `main` or already has uncommitted changes, keep those files in place and use a separate task worktree when a remote is available.
- Keep a task’s edits on its branch. When asked to publish, push the task branch and open a pull request into `main`, with a summary and verification results. The team reviews and merges the pull request.
- For unfamiliar Godot code on Windows, use `tools/godot-lookup/Find Godot Code.cmd` if present, then read relevant source ranges. Use targeted source search when the tool is absent or its results are incomplete.
