# AI development workflow — status and integration boundaries

## Shared contract

GitHub issues and draft PRs are the durable task records; Discord is the team interface. Use [AGENTS.md](../AGENTS.md) and [team workflow](TEAM-WORKFLOW.md) for branch isolation, overlap checks and human approval. An alternative coding agent can use the same issue brief, but must follow those rules and provide verification. Do not assume a connection to GitHub automatically enforces them.

## Deployment versus main

At the documentation baseline (6e3c963d), the source for the GPU worker and Discord issue pilot is under active development in [PR #31](https://github.com/PeterFacina/richs-houseboat/pull/31); function-level retrieval work is tracked in [PR #28](https://github.com/PeterFacina/richs-houseboat/pull/28). Consult the latest PR and deployment status rather than assuming main contains every deployed component. The team reports that automatic issue brief posting and gameplay issue-to-PR review are operational. The training capture rollout and approved-only export require live validation; no fine-tune is established by this documentation. Keep private deployment configuration and credentials out of the repository.

## Acceptance and learning

Preserve the original issue, model request/context and initial brief; record implementation agent/model if known, playtest corrections and linked PR. A human-approved corrected brief is separate from a merged game change. Do not label unapproved examples as training-ready. Evaluate changes on held-out whole issues and measure actual acceptance rounds, regression rate and token usage rather than assuming documentation saves tokens. See PR #31 for the current implementation; this guide changes no worker behavior or training schema.
