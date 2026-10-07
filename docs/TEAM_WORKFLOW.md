# Team Workflow — 3 People + Codex

## Roles

- **Phúc:** repository/integration owner, final PR review and merge.
- **Vy / Trâm / Phúc:** each may own feature tasks end-to-end.
- Shared-core changes are coordinated through Phúc to avoid concurrent edits.

## Branch model

```text
main
 ^
 |  reviewed PR
 |
 +-- feat/home-daily-prompt
 +-- feat/journal-editor
 +-- feat/study-screen
 +-- feat/album-grid
 +-- feat/ai-reflection-api
```

Do not keep one branch per person for the whole project.

## Daily working sequence

```bash
git checkout main
git pull origin main
git checkout -b feat/<task-name>
```

Use Codex only on that task branch.

Before PR:

```bash
git status
git diff
# run relevant tests/build
git add .
git commit -m "feat: ..."
git push -u origin feat/<task-name>
```

Open a Pull Request. Phúc reviews, requests changes if needed, and merges.

After another PR is merged, developers should update their open branch regularly:

```bash
git checkout main
git pull origin main
git checkout feat/<task-name>
git merge main
```

For this team, merging `main` into a feature branch is intentionally preferred over requiring rebase expertise.

## Suggested ownership boundaries

Ownership should follow **feature areas**, not permanent technology layers. Example:

- Person A: Home/Journal tasks
- Person B: Study/Challenges tasks
- Person C: Album/Explore tasks

Backend/API tasks can be owned by the same person implementing that feature when practical, while shared backend core remains protected.

## Codex rule

Every prompt should include an allowlist. Example:

```text
Allowed:
- mobile/lib/features/study/**

Do not modify:
- mobile/lib/core/**
- mobile/lib/navigation/**
- backend/**
```

If Codex needs a shared-core change, stop and make it explicit instead of allowing a broad autonomous refactor.
