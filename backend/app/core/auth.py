"""Supabase Auth JWT verification; never trust client-submitted owner IDs.

Only asymmetric ES256/RS256 Supabase access tokens are accepted. If this
project still uses legacy HS256 signing, migrate to asymmetric signing keys
before enabling this FastAPI JWT verifier; do not put JWT secrets in Flutter.
"""
from dataclasses import dataclass
from functools import lru_cache
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import InvalidTokenError, PyJWKClient, PyJWKClientConnectionError, PyJWKClientError

from app.core.config import Settings, get_settings


@dataclass(frozen=True)
class AuthenticatedUser:
    user_id: UUID
    email: str | None


bearer_scheme = HTTPBearer(auto_error=False)


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing authentication token",
        headers={"WWW-Authenticate": "Bearer"},
    )


@lru_cache(maxsize=8)
def _jwks_client(jwks_url: str) -> PyJWKClient:
    return PyJWKClient(jwks_url, cache_jwk_set=True, lifespan=300, timeout=5)


def verify_supabase_token(
    token: str,
    *,
    settings: Settings | None = None,
    jwks_client: PyJWKClient | None = None,
) -> AuthenticatedUser:
    """Verify signature, issuer, audience, lifetime and authenticated role."""
    settings = settings or get_settings()
    base = (settings.supabase_url or "").rstrip("/")
    if not base.startswith("https://") or not base.endswith(".supabase.co"):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase Auth URL is not configured",
        )

    try:
        header = jwt.get_unverified_header(token)
        if header.get("alg") not in ("ES256", "RS256") or not header.get("kid"):
            raise InvalidTokenError("Unsupported or unsigned Supabase token")

        client = jwks_client or _jwks_client(
            f"{base}/auth/v1/.well-known/jwks.json"
        )
        public_key = client.get_signing_key_from_jwt(token).key
        claims = jwt.decode(
            token,
            public_key,
            algorithms=["ES256", "RS256"],
            issuer=f"{base}/auth/v1",
            audience="authenticated",
            options={"require": ["iss", "aud", "exp", "iat", "sub"]},
            leeway=10,
        )
        if claims.get("role") != "authenticated":
            raise InvalidTokenError("Token is not an authenticated user")
        user_id = UUID(claims["sub"])
        if user_id.int == 0:
            raise InvalidTokenError("Empty user identity")
        email = claims.get("email")
        if email is not None and not isinstance(email, str):
            raise InvalidTokenError("Invalid email claim")
    except PyJWKClientConnectionError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase signing keys are temporarily unavailable",
        ) from exc
    except (InvalidTokenError, PyJWKClientError, ValueError, TypeError, KeyError) as exc:
        raise _unauthorized() from exc

    return AuthenticatedUser(user_id=user_id, email=email)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> AuthenticatedUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthorized()
    return verify_supabase_token(credentials.credentials)


def block_unowned_journals(
    current_user: AuthenticatedUser = Depends(get_current_user),
) -> None:
    """B02 fail-closed: B04 must add journal user_id + owner filters first.

    Requiring a token alone is NOT sufficient: legacy journal_entries rows
    have no owner. Block the entire CRUD surface until B04 replaces this gate.
    """
    del current_user
    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Journal API is awaiting owner migration (B04)",
    )
