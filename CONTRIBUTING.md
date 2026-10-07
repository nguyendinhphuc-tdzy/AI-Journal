# Contributing

## Branch naming

Use short-lived task branches:

- `feat/home-daily-prompt`
- `feat/journal-write-screen`
- `feat/ai-reflection-api`
- `feat/study-framework-list`
- `fix/journal-save-error`
- `docs/api-contract`
- `chore/backend-config`

Avoid personal long-lived branches such as `vy`, `tram`, or `phuc`.

## Commit style

Examples:

```text
feat: add daily prompt card
feat: create journal API
fix: handle empty journal content
refactor: extract journal repository
chore: configure local database

docs: document reflection endpoint
```

## Pull requests

Every PR should:

- solve one task;
- list affected modules;
- state API/DB changes explicitly;
- include screenshots for UI work when useful;
- include test/build results;
- be reviewed before merge.

Phúc is the final integration reviewer for `main`.
