"""JWT verifier tests without hitting real Supabase or secrets."""
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from uuid import uuid4

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import HTTPException

from app.core.auth import verify_supabase_token
from app.core.config import Settings


USER_ID = str(uuid4())
SUPABASE_URL = "https://test-ref.supabase.co"
PRIVATE_KEY = ec.generate_private_key(ec.SECP256R1())
OTHER_KEY = ec.generate_private_key(ec.SECP256R1())


class MockJWKClient:
    def get_signing_key_from_jwt(self, token: str):
        return SimpleNamespace(key=PRIVATE_KEY.public_key())


def config() -> Settings:
    return Settings(database_url="sqlite://", supabase_url=SUPABASE_URL)


def token(**overrides):
    now = datetime.now(timezone.utc)
    claims = {
        "sub": USER_ID,
        "email": "test@example.com",
        "iss": SUPABASE_URL + "/auth/v1",
        "aud": "authenticated",
        "role": "authenticated",
        "iat": now,
        "exp": now + timedelta(minutes=5),
    }
    claims.update(overrides)
    return jwt.encode(claims, PRIVATE_KEY, algorithm="ES256", headers={"kid": "test-key"})


def assert_denied(raw: str):
    with pytest.raises(HTTPException) as err:
        verify_supabase_token(raw, settings=config(), jwks_client=MockJWKClient())
    assert err.value.status_code == 401


def test_valid_supabase_access_token():
    identity = verify_supabase_token(token(), settings=config(), jwks_client=MockJWKClient())
    assert str(identity.user_id) == USER_ID
    assert identity.email == "test@example.com"


def test_wrong_signature_rejected():
    t = jwt.encode(
        {"iss": SUPABASE_URL + "/auth/v1", "aud": "authenticated",
         "sub": USER_ID, "role": "authenticated",
         "iat": datetime.now(timezone.utc),
         "exp": datetime.now(timezone.utc) + timedelta(minutes=5)},
        OTHER_KEY, algorithm="ES256", headers={"kid": "test-key"},
    )
    assert_denied(t)


@pytest.mark.parametrize("overrides", [
    {"iss": "https://another.supabase.co/auth/v1"},
    {"aud": "anon"},
    {"role": "anon"},
    {"sub": "not-a-uuid"},
    {"exp": datetime.now(timezone.utc) - timedelta(minutes=10)},
])
def test_bad_claims_rejected(overrides):
    assert_denied(token(**overrides))


def test_hs256_rejected_before_verification():
    bad = jwt.encode(
        {"sub": USER_ID},
        "not-the-supabase-secret", algorithm="HS256", headers={"kid": "test-key"},
    )
    assert_denied(bad)


def test_missing_configuration_fails_closed():
    with pytest.raises(HTTPException) as err:
        verify_supabase_token(token(), settings=Settings(database_url="sqlite://", supabase_url=None))
    assert err.value.status_code == 503
