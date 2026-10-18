# Product Scope — Current Decision

## Product principle

**Journal first, AI second.** The user writes before AI intervenes. AI should help the user reflect rather than turn the journal into a chatbot.

## Core daily loop

```text
Home
  -> Daily Prompt
  -> Write Journal
  -> optional Go Deeper
  -> Finish Entry
  -> AI Reflection
  -> Journal Saved
  -> Return
```

## Four product areas

### 1. Home / Journal — core functional area

- Daily prompt
- Nudaeng/mascot state
- Timeline / journal history
- Write entry
- Markdown-like writing experience
- optional image/voice affordances in UI
- optional Go Deeper
- AI Reflection

### 2. Study & Challenges — early secondary area

- Journaling framework categories
- Guided journal cards
- Challenges
- AI "Recommend Me" concept

### 3. Album — early secondary area

- Personal memory space
- Photo + journal memories
- Timeline / collection
- Sharing concept may be explored later

### 4. Explore / Map — prototype depth first

- Mood places
- Personal map
- Connect journal memories to places

## Onboarding

```text
Welcome / quote
-> Why do you want to journal?
-> How familiar are you with journaling?
-> What you get: AI Reflection / Privacy / Personalized Insights
-> First Guided Journal
-> First AI Insight
-> Privacy
-> Reminder setup
-> Home
```

## UI identity

- soft
- playful
- cozy
- calm
- diary-like
- quiet + natural + slightly nostalgic

Avoid a stereotypical "AI app" visual language dominated by purple gradients, robots, and excessive sparkle.

## Current implementation priority

### Sprint UI 01

Splash -> Home -> Daily Prompt -> Write Journal -> fake AI Reflection -> Home.

### Sprint UI 02

Study + Album + animation + mascot placeholders.

### Sprint Functional 01

Database + save journal + image plumbing.

### Sprint AI 01

AI Reflection + Go Deeper.

### Sprint Experience

Sound + animation + haptic + transitions.

## Confirmed MVP backend decisions (2026-10-18)

- Supabase PostgreSQL (FastAPI-only data gateway) and Supabase Auth email/password.
- Streak is based on a **successfully saved, nonblank journal-writing action**, not on opening the app; one completed day per user-local date.
- Flutter Explore renders with **MapLibre + OpenFreeMap**, with manual pin drop. Search/address lookup is a distinct provider integration (proposed: Geoapify through FastAPI).
- A saved place supports multiple private notes and many-to-many links with journals.
- Consult `docs/DECISIONS.md`, `docs/DATABASE_SCHEMA.md` and `docs/API_CONTRACT.md` for implementation rules. These features remain planned until the corresponding PRs merge.

## Still unresolved / deferred

- Production AI provider/model.
- Voice-input depth, image storage and sharing.
- Study/Album deeper backend behavior and persistence.
- Rights/licensing for referenced mascot assets.

The product principle remains **Journal first, AI second**.
