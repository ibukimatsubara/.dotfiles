---
name: issue-to-pr-delivery
description: Drive a repository change from GitHub issue or task through implementation, verification, pull request, review, and an explicitly authorized merge. Use when the user asks for issue creation, worktree-based development, a PR, review feedback handling, or end-to-end delivery.
---

# Issue to PR Delivery

Keep the delivery traceable while preserving the user's authority over external and irreversible actions.

## Establish the delivery state

- Read all applicable `AGENTS.md` or repository instructions before changing files.
- Inspect the worktree, current branch, remotes, related issue or PR, and existing user changes. Preserve unrelated edits.
- Reuse an existing issue or PR when one already covers the request. Create one only when requested or when issue creation is clearly part of the requested workflow.
- Whenever mentioning an issue or PR, include both its number and title, for example `[#658] AIデッキ50枚生成・保存の欠損防止`.
- Use a dedicated branch or worktree when the repository convention, task size, or user request calls for isolation. Do not create extra worktrees for trivial work without a reason.

## Implement and verify

- Convert the issue acceptance criteria into observable checks before coding.
- Make the smallest coherent change that satisfies those criteria and follows repository conventions.
- Run focused tests first, then the broader checks justified by risk. Include formatting, lint, type checks, build, migrations, and visual QA only where relevant.
- Review the final diff for correctness, regressions, accidental files, secrets, and missing tests. Do not silently weaken or delete tests to obtain a green result.
- If verification is blocked, report the exact command, failure, and what remains unverified.

## Publish and close the loop

- Commit, push, create or update the PR only when those external mutations are within the user's request.
- Make the PR body trace the issue, implementation, verification evidence, risks, and any manual checks.
- Address review feedback by validating the feedback against the code rather than applying it mechanically.
- Do not merge, publish a release, delete a branch or worktree, or close an issue unless the user requested that action or the active workflow explicitly grants it.
- Before merging, confirm required checks and requested user-facing verification are complete. After merging, verify the resulting state and clean up only safe, clean worktrees.
