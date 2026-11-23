# Rich’s Houseboat Discord issue pilot

Run this on the Windows host with Node.js 24. The pilot builds a fixed Codex prompt for a notes-only task. It can run before Game Prompt Studio or Ollama is connected.

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
