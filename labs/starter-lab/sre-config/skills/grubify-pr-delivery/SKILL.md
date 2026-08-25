---
metadata:
  api_version: azuresre.ai/v2
  kind: Skill
name: grubify-pr-delivery
description: Create a minimal RCA-backed pull request in the configured Grubify repository after a production incident has been diagnosed.
tools:
  - FindConnectedGitHubRepo
  - GetIaCForGitHub
  - ExecutePythonCode
  - SearchMemory
---

# Grubify Pull Request Delivery

Use this skill only after telemetry and source evidence establish a root cause in
`GITHUB_REPO_PLACEHOLDER`.

1. Resolve the connected repository with `FindConnectedGitHubRepo`; refuse any repository other
   than `GITHUB_REPO_PLACEHOLDER`.
2. Branch from the current default branch as `fix/incident-<incident-id>-<symptom>`.
3. Make the smallest source change that fixes the proven cause. For the cart path, remove unbounded
   request-data retention without changing the API contract.
4. Build or test the touched project before committing. Do not claim a check that was not run.
5. Commit with `fix(<area>): <symptom and cause>`.
6. Open a pull request against the default branch. Include incident URL or ID, symptom, impact,
   telemetry evidence, root cause, code change, validation, rollout, and rollback.
7. Return the pull request URL to the incident thread.

Never merge, approve, force-push, deploy, change workflow permissions, expose credentials, or modify
files unrelated to the proven root cause. A human merge is the release approval boundary.