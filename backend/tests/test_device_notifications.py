"""FCM devices and business events are tested without Firebase or live Supabase."""
from uuid import uuid4, UUID
from hashlib import sha256
import importlib
import httpx
from app.core.auth import AuthenticatedUser, get_current_user
from app.main import app
from app.core.database import SessionLocal
from app.models.device_token import DeviceToken
from test_api import client


def test_device_registration_is_owner_scoped_and_rotatable():
    token_a = "FCM_TOKEN_A_" + "a" * 40
    token_b = "FCM_TOKEN_B_" + "b" * 40
    owner = AuthenticatedUser(user_id=uuid4(), email="device1@test.local")
    other = AuthenticatedUser(user_id=uuid4(), email="device2@test.local")
    route = "/api/v1/devices"
    try:
        app.dependency_overrides.clear()
        assert client.post(route, json={
            "token": token_a, "installation_id": "android-test-001",
            "platform": "android"}).status_code == 401
        app.dependency_overrides[get_current_user] = lambda: owner
        assert client.post(route, json={"token": "short",
            "installation_id": "android-test-001", "platform": "android"}).status_code == 422
        payload = {"token": token_a, "installation_id": "android-test-001",
                   "platform": "android"}
        assert client.post(route, json=payload).json() == {"registered": True}
        assert client.post(route, json=payload).status_code == 200
        with SessionLocal() as db:
            row = db.get(DeviceToken, sha256(token_a.encode()).hexdigest())
            assert row is not None and row.user_id == owner.user_id
            assert row.token == token_a
        # Same installation, rotated FCM token: old one is removed.
        assert client.post(route, json={**payload, "token": token_b}).status_code == 200
        with SessionLocal() as db:
            assert db.get(DeviceToken, sha256(token_a.encode()).hexdigest()) is None
            assert db.get(DeviceToken, sha256(token_b.encode()).hexdigest()) is not None
        # New account on same emulator must not keep sending to prior account.
        app.dependency_overrides[get_current_user] = lambda: other
        assert client.post(route, json={**payload, "token": token_b}).status_code == 200
        with SessionLocal() as db:
            assert db.get(DeviceToken, sha256(token_b.encode()).hexdigest()).user_id == other.user_id
        app.dependency_overrides[get_current_user] = lambda: owner
        assert client.request("DELETE", route, json={"token": token_b}).status_code == 204
        with SessionLocal() as db:
            assert db.get(DeviceToken, sha256(token_b.encode()).hexdigest()) is not None
        app.dependency_overrides[get_current_user] = lambda: other
        assert client.request("DELETE", route, json={"token": token_b}).status_code == 204
        assert client.request("DELETE", route, json={"token": token_b}).status_code == 204
        with SessionLocal() as db:
            assert db.get(DeviceToken, sha256(token_b.encode()).hexdigest()) is None
    finally:
        app.dependency_overrides.clear()


def test_fcm_payload_only_safe_metadata_and_invalid_token_detection():
    from app.modules.devices.push import fcm_payload, send_fcm
    actual = fcm_payload("fcm-secret", "message", {"conversation_id": "uuid-conversation"})
    assert actual["message"]["notification"]["body"] == "Bạn có tin nhắn mới"
    assert actual["message"]["android"]["notification"]["visibility"] == "PRIVATE"
    assert "message_text" not in actual["message"]["data"]
    assert "note" not in str(actual)
    sent = []
    def fake(req):
        assert req.url.host == "fcm.googleapis.com"
        assert req.url.path == "/v1/projects/fcm-project/messages:send"
        assert req.headers["Authorization"] == "Bearer fake-oauth"
        sent.append(req.read().decode())
        return httpx.Response(200, json={"name": "projects/fcm-project/messages/1"})
    with httpx.Client(transport=httpx.MockTransport(fake)) as c:
        assert send_fcm(c, "fcm-project", "fake-oauth", "fcm-secret",
                        "message", {"conversation_id": "uuid-conversation"}) is False
    assert len(sent) == 1 and "private journal" not in sent[0]
    with httpx.Client(transport=httpx.MockTransport(
        lambda req: httpx.Response(404, json={
          "error": {"status": "UNREGISTERED"}}))) as c:
        assert send_fcm(c, "fcm-project", "fake-oauth", "fcm-secret",
                        "message", {}) is True
    with httpx.Client(transport=httpx.MockTransport(
        lambda req: httpx.Response(404, json={
          "error": {"status": "NOT_FOUND"}}))) as c:
        assert send_fcm(c, "fcm-project", "fake-oauth", "fcm-secret",
                        "message", {}) is False


def test_push_emitted_once_after_successful_business_commit(monkeypatch):
    friendmod = importlib.import_module("app.modules.friends.router")
    chatmod = importlib.import_module("app.modules.messages.router")
    sharemod = importlib.import_module("app.modules.shares.router")
    events = []
    def capture(uid, kind, data):
        events.append((uid, kind, data))
    monkeypatch.setattr(friendmod, "send_push_to_user", capture)
    monkeypatch.setattr(chatmod, "send_push_to_user", capture)
    monkeypatch.setattr(sharemod, "send_push_to_user", capture)
    a = AuthenticatedUser(user_id=uuid4(), email="push-a@example.com")
    b = AuthenticatedUser(user_id=uuid4(), email="push-b@example.com")
    try:
        app.dependency_overrides[get_current_user] = lambda: a
        assert client.post("/api/v1/friends/requests",
                           json={"user_id": str(b.user_id)}).status_code == 201
        assert events == [(b.user_id, "friend_request", {"sender_id": str(a.user_id)})]
        assert client.post("/api/v1/friends/requests",
                           json={"user_id": str(b.user_id)}).status_code == 409
        assert len(events) == 1
        app.dependency_overrides[get_current_user] = lambda: b
        assert client.post(f"/api/v1/friends/{a.user_id}/accept").status_code == 200
        assert events[-1] == (a.user_id, "friend_accepted",
                              {"friend_id": str(b.user_id)})
        app.dependency_overrides[get_current_user] = lambda: a
        cid = client.post("/api/v1/conversations",
                          json={"friend_id": str(b.user_id)}).json()["id"]
        body = {"client_id": "push-client-id-01", "text": "SUPER SECRET DIARY"}
        sent = client.post(f"/api/v1/conversations/{cid}/messages", json=body)
        assert sent.status_code == 200, sent.text
        assert events[-1] == (b.user_id, "message", {"conversation_id": cid})
        before = len(events)
        assert client.post(f"/api/v1/conversations/{cid}/messages", json=body).status_code == 200
        assert len(events) == before
        place = {"name": "Địa điểm riêng", "latitude": 10.77, "longitude": 106.7}
        assert client.post("/api/v1/place-shares", json={
            "recipient_ids": [str(b.user_id)], "place": place}).status_code == 201
        assert events[-1] == (b.user_id, "message", {"conversation_id": cid})
        shared = client.post("/api/v1/memory-shares", json={
            "recipient_ids": [str(b.user_id)],
            "text": "PRIVATE MEMORY CAPTION",
            "place": {"label": "Quận 1", "latitude": 10.77, "longitude": 106.7}})
        assert shared.status_code == 201, shared.text
        assert events[-1] == (b.user_id, "memory_share",
                              {"share_id": shared.json()["id"]})
        # The push payload must never contain diary text, raw GPS or photos.
        assert "PRIVATE" not in str(events)
        assert "10.77" not in str(events)
        assert len(events) == 5
    finally:
        app.dependency_overrides.clear()
