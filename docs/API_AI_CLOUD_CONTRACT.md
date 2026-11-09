# AI Cloud APIs (B1, C5/C6, B2/B3, D) — Integration Contract

**Base:** `/api/v1`. All routes require a **verified Supabase JWT**. These routes belong to the new backend PR and do not automatically synchronize Vy's Flutter `AnalysisArchive` or `SavedQuotes`; mobile adapter changes are a follow-up. No production database migration has been executed by this PR.

## C5/C6 — richer AI reflection

`POST /ai/reflection`: same body as before: `{"content": "...", "mood": "..." }`; `content` 1–8000 nonblank characters; quota 12/min/user per process.

Response still includes required `emotion`, `observation`, `reflection`, `question`. New optional keys: `title`, `analysis`, `topics` (up to 8), `quote` (always null until approved, server-validated quote catalog exists), plus server-computed `mood_group` and `mood_score`. The 10 group IDs are `joy`, `grateful`, `calm`, `hopeful`, `mixed`, `tired`, `anxious`, `afraid`, `angry`, `sad`; corresponding display scores are 90, 85, 80, 72, 55, 40, 35, 30, 30, 25. Two matched groups give `mood_group="mixed"` and the average score. Unmatched words give **null** group and score, never an invented value. Matching intentionally mirrors `mobile/lib/features/insights/data/emotion_scale.dart`, including "không vui" negation. These scores are **display conventions, not a validated medical scale**.

No claim that text generations are always grammatically correct. The saved analysis result stores the full normalized response.

## B1 — saved journal analyses

| Method | Path | Contract |
| --- | --- | --- |
| POST | `/journals/{id}/analysis` | Optional `{"force":false}`. Infer from the **already saved** journal content, not client-supplied unsaved text. Idempotent by default if an analysis exists for the current body version; `force:true` regenerates. 200 with `AnalysisRead`; 422 if saved body is outside AI input limit, 404 if journal unowned, 409 if edited during inference. Counts against AI quota. |
| GET | `/journals/{id}/analysis` | Cached analysis only (no inference). Returns `AnalysisRead`, or 404 if not saved or not owned. |
| GET | `/journals?include=analysis` | Existing cursor-paginated `JournalPage` with an extra `analysis` per item (null if absent). Unspecified `include` preserves the previous payload shape. |
| DELETE | `/journals/{id}` | Existing behavior; FK cascade also deletes the analysis, no orphan data. |

`AnalysisRead`: `id` (UUID), `journal_id` (integer), `body_version`, `saved_at` (UTC), `stale` (boolean), `analysis` (full reflection JSON), `feedback` (`up|down|null`). Editing a journal increments `body_version` and marks old analysis stale. Only refreshed analysis with matching body version counts in weekly trends. Owner UUID comes from verified JWT only.

When migrating local `AnalysisArchive` to server, **do not rerun Ollama automatically on previously recorded private entries** without consent; a separate upload/import contract and opt-in review would be required. A GET from a different phone will see analysis created via B1, not older local-only records unless imported.

## B2 — Saved Quotes

| Method | Path | Contract |
| --- | --- | --- |
| POST | `/saved-quotes` | `{"text":"...","author":"...","source":null}`, nonblank text (max 1000), author (max 160), source (max 250). Idempotent by user+text; returns saved row with UUID. |
| GET | `/saved-quotes?limit=50&offset=0` | `{"items":[{"id","text","author","source","saved_at"}],"next_offset":null|number}`. |
| DELETE | `/saved-quotes/{quote_id}` | Deletes only the owner's quote; 204 or 404. |

Quote text/author are **client-submitted** and not automatically verified. Frontend should submit only quotes selected from its approved local catalog; the model must **not** invent quote attributions.

## B3 — analysis feedback

`PUT /journals/{id}/analysis/feedback` `{"rating":"up"}`, `{"rating":"down"}` or `{"rating":null}`. Updates a currently valid private analysis, no journal text is re-sent; returns `AnalysisRead`. Unowned/absent analysis → 404, stale analysis → 409, invalid rating → 422. Regeneration resets feedback because it applies to the old interpretation.

## D — weekly insights

`GET /insights/week?start=YYYY-MM-DD&generate_summary=false` (required **Monday in user's timezone**). Returns:

```json
{
  "start": "2026-10-26", "end": "2026-11-01",
  "days": [
    {"date":"2026-10-26","journal_count":0,"analyzed_count":0,"score":null}
  ],
  "top_emotions": [{"mood_group":"calm","count":2}],
  "summary": null,
  "summary_status": "not_requested"
}
```

`days` has **seven rows**, Monday–Sunday, scores mean of classified, current-`body_version` analyses only, null if none. `journal_count` is number of cloud journals created on that date; `analyzed_count` is number with any fresh analysis. No fake points or static text.

To **explicitly request an AI-written narrative**, call with `generate_summary=true`. Only aggregate counts and scores (not raw journal content) are sent to the configured Ollama provider. Request is subject to the existing **per-process AI quota** and the resulting text is cached per user/week/fingerprint. Empty weeks and development mock mode return `summary:null` and a truthful status (`no_data` or `unavailable`); cached valid narrative returns `ready`. Adding/editing/deleting journal/analysis invalidates the cache fingerprint automatically; do not mistake `summary_status=not_requested` for a generated summary.

## Security and deployment requirements

- Migration `20261029_16` creates `journal_analyses`, `saved_quotes`, `weekly_insights` with unique user-scoped keys; analysis has composite FK to the **owned** journal and `ON DELETE CASCADE`. RLS is **enabled** and direct `anon`/`authenticated` grants are revoked in Supabase Postgres; only authenticated FastAPI may query through its configured server DB connection.
- **Deploy migration in the intended development environment before enabling endpoints.** This PR did not alter the live Supabase database. Before deploying, confirm prior revision `20261028_15`, DB password rotation, backup and RLS configuration.
- A login choice to turn AI off must be honored by Flutter. Server cannot infer a legacy device-only opt-out from JWT: `POST /journals/{id}/analysis` and `generate_summary=true` are explicit operations which the UI must disable unless AI is enabled. Update and approve the privacy policy describing cloud storage of AI analysis and scores **before rollout**.
- Keep the current local screens and cached data while implementing authenticated cloud repository adapters. For saved analyses, reconcile by `journal_id + body_version`, never overwrite a newer analysis with older local data.
- Preview unit tests use disposable SQLite and mock AI. No real journal text is sent to Ollama by tests.
