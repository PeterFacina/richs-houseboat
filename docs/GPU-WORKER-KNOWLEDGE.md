# GPU worker knowledge

The [controlled rollout runbook](GPU-CONTROLLED-ROLLOUT.md) covers the single-issue candidate, preview, rollback and private development outcomes.

## How briefs get their context

1. The existing Discord bot queues an issue on GitHub. The GPU worker skips reports that already have a marked brief and accepts one generation at a time.
2. The worker's loopback Prompt Studio reserves the generation slot and checks the GitHub `main` ref. When it changes, Git fetches a pinned commit into a dedicated sparse source checkout. The worker's own code and the team's development checkouts are separate.
3. `tools/knowledge/index.py` reuses declarations and literal references for files with the same SHA-256. Studio updates changed chunks, removes deleted paths, and commits both the search index and the source revision in one SQLite transaction. The worker reuses the persisted index after a restart. A failed update leaves that transaction intact. Briefs using the last verified revision carry a stale notice. If no verified index exists, the issue stays pending.
4. Studio includes the opening paragraph of [Game identity](GAME-IDENTITY.md) from the pinned revision. It combines matching declarations, excerpts, subsystem guides, direct literal resource references and related open GitHub issue or PR titles. It retrieves at most three live tasks and uses a 5,800-character evidence excerpt budget at the worker's default context setting. It retrieves current issue and PR lists independently of the source revision. Missing or truncated GitHub task lists are recorded as incomplete. Context is untrusted evidence, and Studio applies its normal structured output and export checks.
5. The worker writes the post-guard brief and private model provenance into the training inbox by issue number. It checks for issue edits and existing marked briefs before posting. A rejected draft stays in the private inbox. Human review and approval follow the [training record procedure](../tools/discord-issue-pilot/README.md#training-records).

The standalone Studio continues to use the user's configured workspace and has subsystem guide search. The worker's managed Studio follows `main`. Dynamic Godot calls and runtime dependencies are outside the literal reference index. GitHub task retrieval reads up to 100 open issues and 100 open PRs and omits bodies and diffs from the model request. Review overlap and relevant diffs before acting on a brief.

## Install and verify

- Use Node.js 24, Git with sparse checkout and partial fetch support, Python 3.9 or newer, and the existing local Ollama with `qwen3:14b`. If `python` is an app alias or is absent, set `HOUSEBOAT_KNOWLEDGE_PYTHON` to the path of an installed Python executable. Set it in the worker launcher environment or local `.worker.env`.
- Use a separate worker-code checkout and keep the existing `.worker.env` and Windows user. The GitHub API token keeps Issues read/write permissions and uses Pull requests read when needed. For a private repository, Git itself needs a preconfigured read credential. Fetches run with interactive Git prompts disabled. The worker's API token is excluded from Git and Python child process environments.
- The default source cache is `%LOCALAPPDATA%\HouseboatGpuKnowledge`. An optional `HOUSEBOAT_KNOWLEDGE_DIR` selects another dedicated directory. The training inbox remains at `%LOCALAPPDATA%\HouseboatPromptTraining\examples.sqlite`. Keep both directories private. The worker holds a local SQLite lock for the same Windows user. Operate one worker for the queue across machines.
- Start from `tools/discord-issue-pilot` using `node --env-file=.worker.env gpu-worker.mjs`. Check the printed knowledge revision against GitHub `main` and verify the queue watching message. Confirm that any new brief includes its game knowledge revision and that its private capture has the same revision and publication link.

The smoke test runs against GitHub `main` and Ollama using temporary storage. It prints commit, timing, retrieval and token totals. It reads GitHub tasks and leaves the Discord bot, production training inbox and worker queue alone.

```powershell
node tools/discord-issue-pilot/gpu-knowledge-smoke.mjs
node --test tools/game_prompt_studio/test/studio.test.mjs tools/discord-issue-pilot/*.test.mjs
python -m unittest discover -s tools/knowledge -p 'test_*.py'
```

## Maintenance and rollback

- When a stale notice persists, inspect the reported stage, Git connectivity and credentials, and Python availability. The worker retries at the next queued generation. The current index and source Git checkout may temporarily point at different commits after a failed build. Trust the SQLite revision printed by the worker.
- If the dedicated checkout is damaged, drain and stop the worker, move the entire knowledge cache aside, then restart. The new cache requires network access for its first verified index. Leave the separate training inbox in place. Back up training data using SQLite's backup mechanism or after a clean shutdown.
- For a worker code rollout, stop intake if possible and drain the existing worker. Use a separate checkout of the reviewed revision with the same environment file. Start it once, watch the startup logs, and verify the next agreed Discord report. On rollback, drain and stop the new worker and relaunch the previously verified worker checkout with the existing environment file. A worker from PR #31 will index its own checkout at startup. Published briefs and the training database remain available.

After this refactor merges, update the worker-code checkout to the reviewed revision and restart from that checkout with its existing environment file.

```powershell
git fetch origin main
git switch --detach FETCH_HEAD
Set-Location tools/discord-issue-pilot
node --env-file=.worker.env gpu-worker.mjs
```

Use these commands in the dedicated worker-code checkout with the service drained and stopped. Keep the private environment file at its configured path. The updated worker applies its new sparse layout and refreshes the existing SQLite index automatically, including when the cached revision already matches main. Confirm the printed revision against `git ls-remote origin refs/heads/main` from the code checkout, then verify the knowledge revision on the next agreed report. A running worker deployed on older code still uses its own sparse rules.

The deterministic index already supplies the relationships used here. Graphify refresh remains optional. Any future AI-generated documentation correction should be a human-reviewed proposal with an exact source revision and cited evidence.
