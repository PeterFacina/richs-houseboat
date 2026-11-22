# Rich’s Houseboat team workflow

## One private GitHub repository

| Where | What lives there |
| --- | --- |
| `main` | The latest agreed Godot source and its baked assets. This is the version everyone starts from. |
| `godot-cove/` | The editable game project. Everyone works on this same path from their own branch. |
| `team/<github-name>/` | Each developer’s notes, plans, screenshots by link, and links to their current branches or pull requests. |
| Feature branches | Each developer’s in-progress game versions, one branch per task. Example: `peter/boat-controls`. |
| Issues and pull requests | Shared tasks, ownership, review, and what was tested. |
| Releases | Versioned downloads for players who want to play without cloning. Each release points at the exact commit used to build it. |

Use individual GitHub accounts and give each developer access to the private repository. One shared login is unnecessary. Put decisions the entire team needs in an issue or shared docs. Personal notes can link to those decisions.

## A normal work session

### Windows shortcut

After cloning the private repository, run this from the clone with Git installed:

```powershell
& ".\tools\Start Game Task.cmd" peter boat-controls
```

Use your GitHub name and a short task name. The command fetches `origin/main` and makes a fresh task worktree in a sibling folder. Open the printed folder in Codex and describe the change. It has the shared `AGENTS.md` and uses the exact fetched commit. The original clone and any unfinished work stay in place. For an existing task, reopen its folder instead of running the command again.

To playtest from a task folder, import its `godot-cove/project.godot` in your installed Godot editor. If you use the copy of Godot under the main clone’s `build/godot`, point that executable at the task with `--path ./godot-cove` from the task folder. Each task can share the same engine installation.

When the work is ready, tell Codex **“Test this, then publish my task branch as a draft PR into main.”** Everyone receives the merged changes the next time they start a fresh task. A GitHub login with write access is needed to publish. The starter itself only fetches and creates local work.

### GitHub Desktop alternative

1. **Get current.** In GitHub Desktop, switch to `main`, fetch, and pull. Create a new branch from that version. Leave unfinished work on its existing branch.
2. **Claim one change.** Open or assign an issue and mention the scripts or scenes likely to overlap with a teammate’s work.
3. **Open the clone in Codex.** Tell Codex the issue, the branch, and how you’ll test the change. Update your note under `team/<github-name>/` if it helps with handoff.
4. **Push and review.** Publish the branch and open a pull request into `main`. Use a draft if you want help early. Include what changed, how you tested it, and whether you tested both host and guest.
5. **Integrate.** Peter or the agreed maintainer reviews and merges. Everyone pulls `main` before starting a new task.

To try someone else’s version, fetch and switch to their branch in GitHub Desktop. Keep your own uncommitted edits on your branch before switching. To go back to a previous team build, open Releases or find its tag and commit.

## First upload

- Compare the current workspace with any newer copies on other machines and agree which Godot project is the baseline. Record how it was verified.
- Create one private repository under the agreed owner. Seed it with the selected `godot-cove/` project and baked assets, the launcher or documented engine setup, asset credits, the team notes, and shared Codex instructions. The existing workspace also contains earlier Garry’s Mod tooling. Include it only if the team still needs it.
- Keep Godot’s `.godot/` cache, local saves, virtual environments, Godot executables, raw GIS data, old archives, and generated graph output outside source control. Keep the Godot licenses and required asset credits with any distribution that includes them.
- Confirm a clean clone can open `godot-cove/project.godot` with the agreed engine version. The current Windows launcher expects Godot 4.7.2 under `build/godot`, so document that local setup or ship it in a verified Windows release.
- Invite the team and do one small test pull request before starting parallel gameplay work. Tag the first tested baseline and attach its playable package when one is ready.

The current workspace has no commits or configured Git remote. These notes are local preparation for a shared repository.

## Team task queue

| Status | Where to look |
| --- | --- |
| Ready | [Open tasks ready to start](https://github.com/PeterFacina/richs-houseboat/issues?q=is%3Aissue+is%3Aopen+label%3A%22status%3A+ready%22) |
| In progress | [Tasks someone is working on](https://github.com/PeterFacina/richs-houseboat/issues?q=is%3Aissue+is%3Aopen+label%3A%22status%3A+in+progress%22) |
| Needs Peter | [Tasks waiting for Peter](https://github.com/PeterFacina/richs-houseboat/issues?q=is%3Aissue+is%3Aopen+label%3A%22status%3A+needs+peter%22) |
| Done | [Closed tasks](https://github.com/PeterFacina/richs-houseboat/issues?q=is%3Aissue+is%3Aclosed) |

Give each issue one owner and a clear done condition. When someone claims it, assign them and replace Ready with In progress. Use Needs Peter when it needs his review or a decision. Close the issue once its done condition is met. Link the issue from the draft pull request and keep its handoff section current if you pause.

Ask Codex: **“Check the team task queue. Show me ready tasks nobody has claimed and anything waiting for Peter.”**
