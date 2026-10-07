# Codex Agent Rules — AI Diary

This repository is developed by three people using Codex agents. These rules are mandatory to reduce accidental cross-feature edits and merge conflicts.

## Before coding

1. Confirm the active Git branch is a task branch, never `main`.
2. Read `docs/PRODUCT_SCOPE.md`, `docs/ARCHITECTURE.md`, and `docs/API_CONTRACT.md` when relevant.
3. State the exact task, allowed directories, and forbidden files in the agent prompt.
4. Inspect existing patterns before creating a new abstraction.

## Scope discipline

Do not perform unrelated refactors. Do not rename shared classes or move shared directories unless the task explicitly requests it.

### Shared core — protected by default

Treat these areas as owned by the repository maintainer / integration owner:

- `mobile/lib/core/**`
- `mobile/lib/navigation/**`
- `mobile/pubspec.yaml`
- `backend/app/core/**`
- `backend/app/main.py`
- `backend/requirements.txt`
- `docs/API_CONTRACT.md`
- `docs/ARCHITECTURE.md`

If a feature needs a shared-core change, explain why in the PR and keep the change minimal.

## API contract

Do not silently change endpoint paths, request fields, response fields, status codes, or shared model semantics. Propose contract changes first and update `docs/API_CONTRACT.md` in the same PR after approval.

## Finish checklist

Before reporting completion:

- run `git status` and inspect `git diff`;
- remove unrelated generated files;
- run relevant tests/builds;
- document any incomplete or mocked behavior;
- do not merge the PR yourself.

## Recommended prompt shape

```text
Task: <one concrete task>

Allowed:
- mobile/lib/features/journal/**

Do not modify:
- mobile/lib/core/**
- mobile/lib/navigation/**
- backend/**
- docs/API_CONTRACT.md

Acceptance criteria:
- ...
- ...

Do not perform unrelated refactors.
Run relevant checks before finishing and summarize changed files.
```
