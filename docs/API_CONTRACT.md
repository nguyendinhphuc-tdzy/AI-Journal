# API Contract — v0.1

Base path: `/api/v1`

This is the initial contract for the **core journal vertical slice**. Study, Album, and Explore may use local/mock data until their backend behavior is finalized.

## Health

### `GET /health`

```json
{
  "status": "ok",
  "service": "ai-diary-backend"
}
```

## Daily prompt

### `GET /api/v1/prompts/daily`

Response:

```json
{
  "id": "daily-001",
  "text": "What is something you want to remember about today?"
}
```

## Journal entries

### `GET /api/v1/journals`

Returns newest entries first.

### `POST /api/v1/journals`

Request:

```json
{
  "title": "A calmer afternoon",
  "content": "I felt more relaxed after finishing my task.",
  "prompt": "What made today feel different?",
  "mood": "calm"
}
```

Response: created journal entry.

### `GET /api/v1/journals/{journal_id}`

Returns one journal entry.

### `PUT /api/v1/journals/{journal_id}`

Updates title/content/prompt/mood.

### `DELETE /api/v1/journals/{journal_id}`

Returns HTTP 204.

## AI — Go Deeper

### `POST /api/v1/ai/go-deeper`

Request:

```json
{
  "content": "I felt peaceful today."
}
```

Response:

```json
{
  "question": "What made today feel different from a more stressful day?"
}
```

The UX should limit Go Deeper to a small number of follow-up questions rather than becoming an open-ended chatbot.

## AI — Reflection

### `POST /api/v1/ai/reflection`

Request:

```json
{
  "content": "I finished something I had been worried about all week.",
  "mood": "relieved"
}
```

Response:

```json
{
  "emotion": "relieved",
  "observation": "Finishing the task seems to have reduced some of the tension you were carrying.",
  "reflection": "You may be noticing how much unfinished tasks affect your sense of calm.",
  "question": "What helped you move from worrying about it to actually finishing it?"
}
```

The AI should describe what is supported by the current entry and avoid strong personality/mental-health conclusions.

## Error format

```json
{
  "detail": "Human-readable error message"
}
```
