# Paired gameplay benchmark packets

Run each pair in Kilo against game commit `9097d61064bd0db0330832d1f355cb595bb0f5f7`. The cases, requirements and acceptance criteria were frozen at `4c77e59`. These six prompts are the original export-checked Qwen outputs from the benchmark. Each pair contains the same verbatim player report. Use the [frozen acceptance criteria](../../../tools/discord-issue-pilot/production-cases.json) when reviewing the result.

| Case | Packet A | Packet B | Focus |
| --- | --- | --- | --- |
| HUD pause and FPS | [A](hud-pause-fps/a.txt) | [B](hud-pause-fps/b.txt) | UI state and layout |
| Solo recovery notice | [A](solo-recovery-notice/a.txt) | [B](solo-recovery-notice/b.txt) | Save recovery and feedback |
| Guest car input status | [A](guest-car-input-status/a.txt) | [B](guest-car-input-status/b.txt) | Host authority, replication and HUD |

## Run

1. For each packet, create a clean isolated worktree at the pinned game commit, with distinct Godot user data and no shared local modifications. Import that copy with Godot 4.7.2. Keep it separate from the live worker and from the other arm's source, saves, conversation and implementation.
2. Start a new Kilo task with the same provider, exact model, reasoning setting, editing mode and tool permissions for each arm. Paste the whole packet, with the same boilerplate for local-only edits and test reporting. Keep acceptance criteria for the review rather than adding them to one prompt. Use one initial response to assess first-attempt success.
3. Record the time from submit to the first patch and test handoff. Do not give corrections until that handoff. Preserve the patch, the agent's source navigation and test evidence, and the provider usage totals as local artifacts. Record correction and rerun time separately. Keep telemetry and private captures out of Git.
4. Review both outputs against the frozen criteria and run the same checks per pair. For HUD, capture bounds around pause and resume, starting with diagnostics enabled and disabled at narrow and wide sizes. For saves, use a clean solo fixture with corrupt, missing and valid primary cases and a crew control, then run `verify_ledger_recovery.gd`. For cars, exercise a host and two guests if available, hold the turn, interrupt the driver's input and resume. Verify observer isolation, re-entry and stable vehicle behavior. The existing `verify_vehicle_exit.gd` supplies a broad control. It does not exercise the guest input indicator.
5. Use the [scorecard](scorecard.csv). Record first-attempt success only if the patch satisfies all required checks without a correction. Leave unavailable figures blank and give a reason. Open the arm key only after scoring.

Count an incorrect assumption when the agent uses a contradicted or unsupported factual premise to guide edits or testing. Count an unnecessary source step when its tool action investigates unrelated code without a concrete link to a requirement or failure. Record the exact premise or tool action so a second reviewer can check the count. For quality, record each acceptance item as passed, failed or unverified, and note scope, regressions, maintainability and test coverage. Record human corrections as distinct directions needed after the first attempt. Capture input, output and reasoning tokens separately when the provider reports them, specifying whether input includes cached tokens.

Under Godot 4.7.2 on the pinned game, the existing ledger recovery and vehicle exit scripts passed after a clean asset import with disposable user data. Neither script validates an unimplemented benchmark feature.

## Arm key and reproduction

A is original for HUD and guest car, and deterministic for solo recovery. B is the paired alternate. [Prompt generation records](generation.json) contain model digest, seed, source revision, export status, token counts and timings. The drafts are model outputs. Their assumptions are part of what the trial should evaluate.

Use the commands in the [production candidate report](../README.md) to regenerate against the frozen cases. A CLI runner is included for hosts where Codex can edit inside its sandbox. The six attempted Codex runs on the current Windows host never executed a checkout command because its process policy blocked child shell launches. Kilo could not be launched locally. Patch quality, coding tokens/time, unnecessary exploration, corrections and first-attempt success remain unmeasured.
