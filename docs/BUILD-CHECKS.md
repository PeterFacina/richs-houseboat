# Godot startup checks

The **Godot startup** check runs when a pull request into `main` opens, reopens, or receives new commits. It uses Godot 4.7.2 to import the assets and run the configured main scene headlessly. The engine version should match the supported version when the newest game is added. A pass means startup worked for the first 60 iterations. Use a human playtest for visuals, controls, saves, and multiplayer.

Until the game baseline is committed, changes without `godot-cove/project.godot` skip the startup portion. A PR that removes a project present in its base fails.

## Get alerts in Discord

Use [#build-checks](https://discord.com/channels/1574136192935661588/1574143899122016347) for failures and recoveries. The failure gives you the PR number and a link to the check. Ask Codex to read that check, fix the problem, and push. A pass after a failed run for the same PR gets a recovery message. Routine passes stay quiet. Merged changes still go to **#main-updates**.

The Discord posting credential is the GitHub Actions secret `DISCORD_BUILD_CHECKS_WEBHOOK`. Notifications are for branches in the team repository. To tag individual teammates, set the Actions variable `DISCORD_BUILD_CHECKS_USER_IDS` to JSON mapping each lowercase GitHub username to their Discord user ID. Without a mapping, the message displays the GitHub username.

```json
{"github-username": "123456789012345678"}
```

The check uses a standard GitHub runner and webhook. Keep paid Actions overages disabled if the team wants to stay within its included allowance.
