# Rich’s Houseboat Dev

Copy each section into the channel with the matching name and pin the message.

## #start-here

**Welcome to Rich’s Houseboat.** Use this server to find the team workflow, ask for help, and see what made it into the shared game.

- Read **#github-workflow** before starting a change.
- Use **#prompt-studio** when you need help turning an idea into a clear Codex prompt.
- Follow **#main-updates** for changes that have been merged.
- Use **#general** for questions and discussion. Track tasks and decisions in GitHub so Codex can find them later.

## #github-workflow

**GitHub is where the team shares its work.** The private [Rich’s Houseboat repo](https://github.com/PeterFacina/richs-houseboat) holds the official version on `main`, your work in progress on branches, and team notes under `team/`.

1. Give Peter your GitHub username and accept your invite. On your PC, ask Codex to clone the repo and read `AGENTS.md`.
2. Before editing, ask Codex to check the latest `main`, open tasks, and relevant draft pull requests. If someone already covered it, ask for the link and what remains.
3. For new work, use the Windows task starter documented in the [team guide](https://github.com/PeterFacina/richs-houseboat/blob/main/docs/TEAM-WORKFLOW.md). Reopen the same task folder to continue it another day.
4. Ask Codex to push a draft pull request early. Say what changed, what you tested, and what is left. Peter reviews and merges when ready.

Practice with the [notes-only onboarding task](https://github.com/PeterFacina/richs-houseboat/issues/2). The newest game baseline still needs to be added.

## #prompt-studio

**Game Prompt Studio helps you write a better request for Codex.** The model runs on the host’s GPU PC. Use the private app address the host provides while the app and PC are running.

Type a rough idea such as “Fix the Zero Turn hands,” then copy the generated prompt into your own Codex. Before asking it to edit, check that the prompt states what you want, what should stay the same, how to test it, and that Codex should look for overlapping work on GitHub.

**Next improvement:** add “Check my request.” It asks a clarifying question when needed and prepares a prompt that has Codex explain its understanding and wait for **go**. The existing generator still needs to be imported from the host PC before the group can edit it through GitHub.

## #main-updates

**This channel answers “What changed in the shared version?”** Each announcement links to a merged pull request and includes its short, plain-English summary. Drafts and branches belong in GitHub until merged.

Example: “Merged into main: the steering hands now stay aligned through full left and right turns. Try steering both ways from the driver’s seat.” This is an example of what a future post could look like.

## Enable automatic announcements

1. In Discord, create an incoming webhook for **#main-updates**.
2. In the private GitHub repo, add the URL under **Settings → Secrets and variables → Actions** as the repository secret `DISCORD_MAIN_UPDATES_WEBHOOK`.
3. Publish the workflow at `.github/workflows/discord-main-updates.yml` to `main`. It sends announcements for merged PRs into `main`. A manual run sends a test message. Confirm the test lands in **#main-updates**.

Include a `## What changed?` section in each PR with a sentence teammates can understand. The workflow uses that section and the PR link. It requires no AI API or hosted bot. Keep Actions spending disabled to stay within the included private-repository allowance. Keep the webhook URL in GitHub Secrets.

## Where to see updates

Open [#main-updates](https://discord.com/channels/1574136192935661588/1574136467934941334) to find the announcement and its GitHub pull request link. If a friend cannot open the channel yet, they need to join Rich’s Houseboat Dev first.
