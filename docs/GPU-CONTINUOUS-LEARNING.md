# GPU development and continuous learning

The Discord report commands create a GitHub issue and use the original Discord message as the durable reference for screenshots. The GPU worker records the exact input and evidence for each generated brief. The Codex handoff calls for a fresh task worktree from GitHub `main`, a linked draft PR and human review. When the PR is merged, the worker collects available changed files, review comments and checks. The [dashboard](GPU-DASHBOARD.md) shows GitHub state separately from local evidence and reviewed playtest outcomes.

## Review outcomes and lessons

See the [private training backup and restore runbook](GPU-TRAINING-BACKUP.md) for online snapshots, archive custody and recovery verification.

Use `training-review.mjs show ISSUE` to see the local capture, verified evidence and automatically collected GitHub outcome. Keep this output on the GPU host. Use `training-review.mjs record ISSUE REVIEW.json` for reviewer-approved playtest outcomes and corrected prompt targets. See the [training record format](../tools/discord-issue-pilot/README.md#training-records).

Run `node learning/review-lesson.mjs proposal ISSUE` to prepare a lesson review from its collected merged PR. Record what failed, what succeeded, how it was verified and which functions still demonstrate that behavior. Run `node learning/review-lesson.mjs approve ISSUE REVIEW.json` after human review. The function-aware retriever checks the approved source fingerprints against current main and omits stale or irrelevant lessons. A lesson approval supplies retrieval evidence. A separate approved corrected target and a passed reviewed outcome are required for fine-tuning.

## Configure the local QLoRA runner

Use a private config beside the training inbox. Pin the Hugging Face Qwen3-14B checkpoint and the installed Ollama base model digest. Use a dedicated Python 3.12 environment with CUDA 12.8 PyTorch, Transformers 4.57, PEFT, Accelerate and bitsandbytes. Install the [llama.cpp LoRA converter](https://github.com/ggml-org/llama.cpp/blob/master/convert_lora_to_gguf.py) and its dependencies in the same isolated environment. [PyTorch CUDA packages](https://pytorch.org/get-started/previous-versions/) · [QLoRA requirements](https://huggingface.co/docs/bitsandbytes/v0.49.0/installation)

```json
{
  "trainingHome": "C:/private/HouseboatPromptTraining",
  "workerHeartbeat": "C:/private/HouseboatGpuKnowledge/worker-status.json",
  "holdout": "C:/private/HouseboatPromptTraining/holdout.json",
  "node": "C:/Program Files/nodejs/node.exe",
  "ollama": "C:/private/Ollama/ollama.exe",
  "converter": "C:/private/llama.cpp/convert_lora_to_gguf.py",
  "baseModel": "Qwen/Qwen3-14B",
  "baseRevision": "40c069824f4251a91eefaf281ebe4c544efd3e18",
  "baselineModel": "qwen3:14b",
  "baselineDigest": "replace-with-the-full-installed-digest",
  "minExamples": 24,
  "maxTokens": 3072,
  "epochs": 2,
  "minFreeMiB": 13200
}
```

Prepare a fixed private evaluation file with at least three distinct complete held-out GitHub issues. Each record has an `issue` number, captured `messages` with the system and user inputs, a nonempty `required` list, and an optional `forbidden` list. Reserve issue #84 as a retrieval and hallucination regression case. The evaluator compares schema validity and the same explicit acceptance checks for the active model and the candidate. A human evaluates semantic quality before promotion.

Schedule `python learning/fine_tune.py tick CONFIG.json` every 15 minutes under the worker’s Windows account. The runner uses whole-issue deduplication, reviewed outcomes for the same capture, export checks and held-out exclusion. It waits for an idle GPU and a recent heartbeat from the worker using the shared activity lock. It stores versioned QLoRA checkpoints, imports a separate Ollama candidate and compares it with the active model. The production tag stays available throughout. When a failed run needs an operator retry, pass `--retry` to `tick`; intact checkpoints resume.

After reviewing the evaluation, run `python learning/fine_tune.py promote CONFIG.json --run RUN_ID --reviewer NAME`. `rollback CONFIG.json --reviewer NAME` restores the previous tag. The worker applies the approved selection between issues. Both actions require the local operator account and write an audit record in the private training directory. The dashboard reports status from that directory and has no control for model selection.

## Production verification

Use the isolated worker smoke test on a real report and check its pinned game revision, input provenance, relevance and export guard. Confirm a newly authorized Discord report produces one GitHub draft handoff, opens the Codex worktree and progresses through a human-reviewed PR. Finding an existing GitHub brief is a valid reason to skip generation. Do not reconstruct or label a missing historical capture as if the worker had originally recorded it.

The Windows host rollout uses the pinned `6628321` worker and the verified game index at `59f55b3`. The #84 replay found the parking railing call and its implementation and the isolated Qwen generation passed the export guard. The worker collected five merged PR outcomes with changed files and check results. The GitHub dashboard matched 23 issues against 19 trusted brief publications and six saved runs. The training controller waits for 24 eligible examples and currently records zero. The three private held-out cases use actual issues #66, #69 and #84. The scheduled evaluation and promotion pipeline remains gated until training data is eligible.

The dashboard is served at the Tailscale root and remains reachable at HTTPS port 8443. Prompt Studio is on HTTPS port 8444 with the same database and authorization settings. The new bot attachment note and stronger Codex worktree handoff are repository changes for the Discord bot host. Verify them using an agreed fresh Discord report on that host.
