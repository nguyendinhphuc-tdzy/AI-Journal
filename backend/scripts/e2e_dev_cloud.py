"""Opt-in destructive E2E smoke for a dedicated Supabase Dev test account.

Needs TWO existing authenticated users, signed Supabase access tokens, migrations 09/10
and a running FastAPI connected to that Supabase Dev PostgreSQL.
No account creation, guessed keys, or implicit writes.
"""
import base64
import os
import sys
from datetime import date
from uuid import uuid4

import httpx

# Valid transparent 1x1 PNG.
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/i90AAAAASUVORK5CYII="
)


def require(value: str, meaning: str) -> str:
    if not value:
        raise SystemExit(f"Missing {meaning}; refusing shared Dev writes")
    return value


def request(client: httpx.Client, method: str, url: str, *,
            token: str, status: int, **kwargs):
    response = client.request(method, url, headers={
        "Authorization": f"Bearer {token}",
        **kwargs.pop("headers", {}),
    }, **kwargs)
    if response.status_code != status:
        raise RuntimeError(f"{method} {url}: expected {status}, received {response.status_code}")
    return response.json() if response.content and response.headers.get(
        "content-type", "").startswith("application/json") else None


def main() -> None:
    if "--yes-write-dev" not in sys.argv:
        raise SystemExit("Refusing to create/delete Dev test data without --yes-write-dev")
    root = require(os.getenv("AI_JOURNAL_TEST_API_BASE_URL", ""), "FastAPI URL").rstrip("/")
    a = require(os.getenv("AI_JOURNAL_TEST_JWT_A", ""), "JWT for account A")
    b = require(os.getenv("AI_JOURNAL_TEST_JWT_B", ""), "JWT for independent account B")
    if a == b:
        raise SystemExit("Tokens A and B must belong to different users")
    label = f"e2e-{uuid4().hex[:12]}"
    journal_id = album_id = memory_id = place_id = None
    with httpx.Client(timeout=30) as client:
        try:
            journal = request(client, "POST", root + "/journals", token=a,
                              status=201, json={"title": label, "content": "E2E private journal"})
            journal_id = journal["id"]
            request(client, "GET", f"{root}/journals/{journal_id}", token=a, status=200)
            request(client, "GET", f"{root}/journals/{journal_id}", token=b, status=404)
            album = request(client, "POST", root + "/albums", token=a,
                            status=201, json={"name": label})
            album_id = album["id"]
            request(client, "GET", f"{root}/albums/{album_id}", token=b, status=404)
            memory = request(client, "POST", f"{root}/albums/{album_id}/memories",
                             token=a, status=201,
                             json={"note": "E2E private Memory", "display_date": date.today().isoformat()})
            memory_id = memory["id"]
            photo = f"{root}/albums/{album_id}/memories/{memory_id}/photo"
            request(client, "PUT", photo, token=a, status=200,
                    content=PNG, headers={"Content-Type": "image/png"})
            request(client, "GET", photo, token=a, status=200)
            request(client, "GET", photo, token=b, status=404)
            place = request(client, "POST", root + "/places", token=a,
                            status=201, json={"label": label, "latitude": 10.7769,
                                              "longitude": 106.7009, "provider": "manual"})
            place_id = place["id"]
            request(client, "GET", f"{root}/places/{place_id}", token=a, status=200)
            request(client, "GET", f"{root}/places/{place_id}", token=b, status=404)
            print("PASS: Auth JWT ownership, Journal, Album, Memory, private photo, Saved Place")
        finally:
            # Only resources created by this run can be removed.
            if memory_id is not None:
                request(client, "DELETE", f"{root}/albums/{album_id}/memories/{memory_id}",
                        token=a, status=204)
            if album_id is not None:
                request(client, "DELETE", f"{root}/albums/{album_id}",
                        token=a, status=204)
            if place_id is not None:
                request(client, "DELETE", f"{root}/places/{place_id}",
                        token=a, status=204)
            if journal_id is not None:
                request(client, "DELETE", f"{root}/journals/{journal_id}",
                        token=a, status=204)


if __name__ == "__main__":
    main()
