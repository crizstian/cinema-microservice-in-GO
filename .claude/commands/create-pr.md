---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(gh pr create:*), mcp__github__*
description: Create a GitHub PR from current branch
---

## Context

- Current branch: !`git branch --show-current`
- Git status: !`git status --short`
- Diff summary: !`git diff --stat`

## Task

1. Review current changes.
2. Generate a clear commit message if needed.
3. Ensure branch is pushed.
4. Create a GitHub pull request with a concise title and description.
5. Reference related issues if applicable.
