# AI development workflow — status and integration boundaries

## Shared contract

GitHub issues and draft PRs are the durable task records; Discord is the team interface. Use [AGENTS.md](../AGENTS.md) and [team workflow](TEAM-WORKFLOW.md) for branch isolation, overlap checks and human approval. An alternative coding agent can use the same issue brief, but must follow those rules and provide verification. Do not assume a connection to GitHub automatically enforces them.

## Deployment versus main

The GPU worker, Discord issue pilot and Prompt Studio may be deployed from branches other than main. Check the current source, [open pull requests](https://github.com/PeterFacina/richs-houseboat/pulls) and the operator's deployed revision before asserting what is live. The team reports that automatic issue brief posting and gameplay issue-to-PR review are operational; confirm training capture, export and fine-tuning status separately. Keep private deployment configuration and credentials out of the repository. The worker source reviewed during this documentation change scans its checkout at startup and captures that startup commit; this is not evidence that a running deployment follows main. Do not pull into or mutate a running worker's checkout. A future refresh should use a clean, pinned revision and reindex before accepting work, with matching captured provenance.

## Acceptance and learning

Preserve the original issue, model request/context and initial brief; record implementation agent/model if known, playtest corrections and linked PR. A human-approved corrected brief is separate from a merged game change. Do not label unapproved examples as training-ready. Evaluate changes on held-out whole issues and measure actual acceptance rounds, regression rate and token usage rather than assuming documentation saves tokens. See the current worker source and deployment notes for implementation details; this guide changes no worker behavior or training schema.
