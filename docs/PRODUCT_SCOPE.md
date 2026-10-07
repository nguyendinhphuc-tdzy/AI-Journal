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

## Explicitly unresolved technical/product decisions

The current product document does not finalize:

- PostgreSQL vs Supabase for the shared database;
- the production AI provider/model;
- the exact implementation depth of voice input;
- the exact backend behavior of Study/Album/Explore;
- rights/licensing for the referenced mascot assets.

The codebase keeps these replaceable and does not treat them as finalized decisions.
