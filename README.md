# AI Diary

Starter repository for the team's Android emulator demo of an AI-assisted journaling app.

## Product direction

The current product concept is **journal first, AI second**. The primary daily loop is:

`Daily Prompt -> Write -> optional Go Deeper -> Finish -> AI Reflection -> Save -> Return`

The app has four bottom-navigation areas:

1. **Home / Journal** — daily prompt, writing, AI reflection, timeline.
2. **Study & Challenges** — journaling frameworks, guided journals, challenges, AI recommendation.
3. **Album** — photo + journal memories and personal collections.
4. **Explore / Map** — mood places and a personal map. This is initially a prototype-level area.

The UI identity is quiet, natural, cozy, slightly nostalgic, with a Nudaeng-inspired mascot concept. Do not commit third-party mascot artwork unless the team has permission to use it; placeholder assets are used in this repo.

## Technical scope

- **Mobile:** Flutter, Android emulator target.
- **Backend:** FastAPI.
- **Database:** SQLAlchemy with SQLite as the local default. `DATABASE_URL` is configurable so PostgreSQL/Supabase can be adopted later without restructuring the app.
- **AI:** provider abstraction with a deterministic mock provider by default. A real provider can be plugged in after the team decides which service to use.
- **Deployment:** not required for the current demo scope.

> The source document did not finalize PostgreSQL vs Supabase or a production AI provider. This repository therefore keeps both choices replaceable rather than hard-coding an assumption.

## Repository layout

```text
AI-Diary-Repo-v1/
├── mobile/                 # Flutter source
│   └── lib/
│       ├── core/
│       ├── features/
│       ├── navigation/
│       └── main.dart
├── backend/                # FastAPI + SQLAlchemy
├── docs/                   # architecture, API contract, scope, team workflow
├── scripts/                # local setup helpers
├── .github/                # PR template
├── AGENTS.md               # Codex working rules
└── CONTRIBUTING.md
```

## First-time setup

### 1. Backend

```bash
cd backend
python -m venv .venv
# Windows PowerShell
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open Swagger at `http://127.0.0.1:8000/docs`.

### 2. Flutter Android project

This starter contains the Flutter application source but not generated Android/Gradle boilerplate. On a machine with Flutter installed, run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bootstrap_mobile.ps1
```

or on macOS/Linux:

```bash
bash scripts/bootstrap_mobile.sh
```

Then:

```bash
cd mobile
flutter pub get
flutter run
```

The Android emulator reaches the backend through `http://10.0.2.2:8000`.

## Team workflow

- `main` is the integration branch.
- Nobody runs Codex or develops directly on `main`.
- One task = one short-lived branch = one Pull Request.
- Phúc reviews and merges PRs.
- Every Codex prompt must state allowed directories and forbidden shared-core files.
- Read `AGENTS.md` and `docs/TEAM_WORKFLOW.md` before starting a task.

## Suggested first vertical slice

1. Render Splash/Home/Write/AI Reflection with mock data.
2. Finalize API contract + DB schema in parallel.
3. Connect Save Journal to FastAPI.
4. Connect AI Reflection + Go Deeper.
5. Add Study/Album UI.
6. Keep Explore/Map at prototype depth until the core loop is stable.
