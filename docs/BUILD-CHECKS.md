# Godot startup checks

The **Godot startup** check runs when a pull request into `main` opens, reopens, or receives new commits. It uses Godot 4.7.2 to import the assets and run the configured main scene headlessly. A pass means startup worked for the first 60 iterations. Use a human playtest for visuals, controls, saves, and multiplayer.

On Windows, open the project's Godot file from your task worktree or run the game with the installed executable.

```powershell
& $engine --path godot-cove
```

## Verify the playable load

Time startup from confirming a solo slot or selecting Multiplayer to the first playable frame or visible lobby. Record the renderer and whether the slot was empty or saved. The title reports threaded resource progress, followed by Deep River construction phases and a completed-span count for road generation. Terrain and collision are built before the player is created. Check that the loading screen keeps updating, that a new and saved solo trip both spawn on a valid surface, and that Multiplayer reaches the lobby before enabling play.

## Get alerts in Discord

Use [#build-checks](https://discord.com/channels/1574136192935661588/1574143899122016347) for failures and recoveries. The failure gives you the PR number and a link to the check. Ask Codex to read that check, fix the problem, and push. A pass after a failed run for the same PR gets a recovery message. Routine passes stay quiet. Merged changes still go to **#main-updates**.

The Discord posting credential is the GitHub Actions secret `DISCORD_BUILD_CHECKS_WEBHOOK`. Notifications are for branches in the team repository. To tag individual teammates, set the Actions variable `DISCORD_BUILD_CHECKS_USER_IDS` to JSON mapping each lowercase GitHub username to their Discord user ID. Without a mapping, the message displays the GitHub username.

```json
{"github-username": "123456789012345678"}
```

The check uses a standard GitHub runner and webhook. Keep paid Actions overages disabled if the team wants to stay within its included allowance.
