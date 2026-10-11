"""Safe Supabase PostgreSQL connectivity smoke test (no schema writes)."""

from sqlalchemy import text

from app.core.database import engine


def main() -> int:
    if engine.url.get_backend_name() != "postgresql":
        print("Not using PostgreSQL. Check DATABASE_URL in backend/.env.")
        return 1
    try:
        with engine.connect() as conn:
            assert conn.execute(text("SELECT 1")).scalar_one() == 1
    except Exception as exc:
        print(
            f"Database connection failed: {type(exc).__name__}. "
            "Check Supabase URL, network, and SSL settings."
        )
        return 1
    print("Supabase PostgreSQL connection: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
