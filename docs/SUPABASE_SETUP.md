# Supabase PostgreSQL setup for AI Journal

## Decision and security boundary

The team uses **Supabase hosted PostgreSQL** as the shared development/demo database, with **FastAPI + SQLAlchemy + Alembic** as the only data-access backend.

~~~text
Flutter Emulator --HTTP--> FastAPI --SQLAlchemy--> Supabase Postgres
~~~

Do **not** add a Postgres connection string or database password to Flutter. No Supabase API key, service role key, or personal secret is required in the repository. Supabase Auth and Storage are separate future decisions.

## 1. Create your Supabase project

1. Sign in at https://supabase.com/dashboard and create a project named e.g. AI-Journal.
2. Choose a region reasonably close to your team.
3. Create and privately store a strong database password.
4. Wait until the database is ready.

You must do this from your own Supabase account; this repository does not create a remote project automatically.

## 2. Copy the correct connection string

1. Open your project, click **Connect** at the top of the Supabase Dashboard.
2. Choose **Session pooler** (port **5432**) for local FastAPI development when your PC is IPv4-only. This is not **Transaction pooler** port 6543.
3. Copy the complete connection string. Do **not** guess the pooler hostname or the project-specific database username.
4. Change only the URL prefix from \`postgresql://\` (or \`postgres://\`) to \`postgresql+psycopg://\` for SQLAlchemy's Psycopg 3 driver.
5. Replace the password placeholder with your real password, URL-encoding reserved characters (for example \`@\`, \`#\`, \`?\`, spaces).
6. Add \`?sslmode=require\` (or \`&sslmode=require\` if the copied URL already contains query parameters).

Example with **FAKE** values (do not paste without replacing):

~~~dotenv
DATABASE_URL=postgresql+psycopg://postgres.PROJECT_REF:URL_ENCODED_PASSWORD@ACTUAL_POOLER_HOST:5432/postgres?sslmode=require
~~~

For a direct connection, Supabase typically uses a different host and database username and requires IPv6 unless your project has the IPv4 add-on. Copy the actual string from Connect.

## 3. Configure backend/.env

From \`backend/\`, create an untracked .env:

~~~powershell
Copy-Item .env.example .env
~~~

Replace \`DATABASE_URL\` with your copied and adjusted **Session pooler** URL. Keep \`AI_PROVIDER=mock\` until the AI provider is separately decided.

Optional for Alembic: if your PC supports IPv6, copy the **Direct connection** URL into \`MIGRATION_DATABASE_URL\`, also using \`postgresql+psycopg://\` and SSL. Direct mode is preferred by Supabase for native migration sessions. If direct mode is unreachable over your network, do not set this variable: the migration tool will use Session pooler mode.

**Never paste the real URL into GitHub Issues, PR comments, screenshots, ChatGPT messages, or Flutter source.** Share database access through Supabase's own project/team management where appropriate.

## 4. Verify connection before schema changes

~~~powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m scripts.check_db
~~~

Expected output:

~~~text
Supabase PostgreSQL connection: OK
~~~

This command runs \`SELECT 1\` and does not create or edit tables. If it fails, verify DNS, host, port, credentials, SSL, and whether you chose Session rather than Direct on an IPv4 network.

## 5. Run migrations (only on the intended project)

**Check the Supabase project and DATABASE_URL carefully before running migrations.**

~~~bash
alembic upgrade head
alembic current
alembic check
~~~

The initial migration creates the \`journal_entries\` table and \`alembic_version\` metadata table. Look in **Supabase Dashboard → Table Editor** to verify the journal table exists.

Do not manually recreate the table in SQL Editor. Future schema changes should be Alembic migrations reviewed through Pull Requests.

## 6. Start FastAPI, then connect Android Emulator

~~~bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
~~~

- On your PC: http://127.0.0.1:8000/docs
- In Android Emulator: http://10.0.2.2:8000/api/v1

The Android app should talk to FastAPI, **not directly to the Supabase database**.

## 7. Important privacy limitation of the current demo

The current \`/api/v1/journals\` endpoints do **not** authenticate users or filter journal entries by owner. Anyone who can reach those endpoints could read all journal entries. PostgreSQL permissions / Supabase RLS are **not a substitute** for API authorization when the backend connects as a privileged database role.

Until auth and ownership checks are implemented:
- use **fictional demo content only**;
- keep the backend private to the developer machine/network;
- never use real personal journal data or expose these APIs publicly;
- prioritize user authentication, user_id ownership checks, and authorization before multi-user testing.

## 8. Automated tests (safe without Supabase)

~~~bash
cd backend
pytest -q
~~~

Tests explicitly override both \`DATABASE_URL\` and \`MIGRATION_DATABASE_URL\` to a temporary SQLite database. They never create tables in the shared Supabase project.

## Documentation

- Connection methods and IPv4/IPv6: https://supabase.com/docs/guides/database/connecting-to-postgres
- Pooling and connections: https://supabase.com/docs/guides/database/connecting-to-postgres/pooling-and-limits
