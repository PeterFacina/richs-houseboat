# Rich’s Houseboat Discord issue pilot

Run this on the Windows host with Node.js 24. The pilot builds a fixed Codex prompt for a notes-only task. It can run before Game Prompt Studio or Ollama is connected.

To include a generated brief in each new issue, run an additional loopback-mode Studio instance on the bot host and set `STUDIO_URL=http://127.0.0.1:8765` in the bot's `.env` (use the actual local port). Use a separate Studio data directory and port if Studio's team instance already runs on that PC. Start Studio against the shared game checkout and keep Ollama on loopback. The bot waits for Studio's guarded export before posting the issue. If Studio is busy or rejects the export, the issue is left uncreated and the Discord action can be retried. Keep live testing to agreed notes-only tasks.

1. Install a Discord application in Rich’s Houseboat Dev with the bot and application commands scopes. The bot needs View Channel, Read Message History, and Send Messages in #issues.
2. Make a GitHub fine-grained token restricted to `PeterFacina/richs-houseboat` with Issues write and Pull requests read. The teammate running Codex uses their own repository access for the PR.
3. Give the loopback launcher its own private Tailscale HTTPS origin and route that origin to `http://127.0.0.1:8766`. Keep the existing Studio origin serving Studio. Check that Josh can open the launcher on his PC.
4. From this folder, run `npm ci`. Create a local `.env` with the following values and start the bot with `node --env-file=.env bot.mjs`.

```dotenv
DISCORD_TOKEN=
DISCORD_GUILD_ID=1574136192935661588
DISCORD_CHANNEL_ID=1574157812932673638
DISCORD_ROLE_ID=
GITHUB_TOKEN=
LAUNCH_URL=
LAUNCH_PORT=8766
```

Set `DISCORD_ROLE_ID` to a team role to limit who can submit or claim. With it blank, anyone with access to #issues can use the pilot. Set `LAUNCH_URL` to the private HTTPS origin from step 3. Run one bot process and keep `pilot.sqlite` in the same working directory across restarts. The GitHub credentials and the launch page stay on the host.

## Live smoke test

1. Post an agreed notes-only task in #issues. Right-click the report and select **Apps → Create pilot issue**. Run the action a second time and check both replies point to the same issue.
2. Ask Josh to click **Claim & Open in Codex**. Check the public bot reply reads **In progress · Josh**. Try the claim from a second account and confirm Josh keeps it. Ownership is recorded in the bot database and displayed in Discord.
3. From Josh’s private reply, open the launcher and then **Open in Codex**. Check that Codex opens his Rich’s Houseboat workspace with the prompt filled in before he sends it. His workspace must match the Git remote in `workflow.mjs`.
4. Open a draft targeting `main` with `Fixes #<issue-number>` on its own line in the PR body. Within about a minute, the original bot reply should say **Draft PR open**. Mark the PR ready and watch it change to **Ready for review**. After the maintainer merges it, check for **Merged into main**.

If GitHub issue creation times out, repeat the message action to look for the original issue by its Discord message marker. If no issue is found, confirm in GitHub that creation failed before using a fresh Discord message for the report. A fresh message starts a new pilot record.

## GPU verification for Ethan

Check out this draft PR's head in a separate local worktree on the GPU PC. Run from the checkout root with Node.js 24 and Ollama listening on `127.0.0.1:11434` with `qwen3:14b` installed.

```powershell
node tools/discord-issue-pilot/gpu-smoke.mjs
ollama ps
```

The runner creates a temporary Studio on a free loopback port, indexes the game in the PR checkout, uses the same HTTP adapter as the Discord bot, and prints the export-checked brief. The test uses the Zero Turn report about the driver's hands jerking on a sharp left turn. Guest visibility is still untested. The existing Studio instance and its database can stay running. This test needs no Discord or GitHub token in the bot configuration.

Post a comment on this PR with the tested commit, GPU, model, elapsed time, Ollama's PROCESSOR value, export result, and whether the brief cited `godot-cove/lawn_mower.gd` and kept guest visibility unverified. Include the brief in the comment. If the test fails, include the error and the last completed step. Keep credentials and machine-specific paths out of the comment.
