# Tin nhắn (messages between friends on the app)

Decided 30/10/2026 (Vy):

- A fifth tab, "Tin nhắn", after Khám phá.
- One conversation per pair of friends on the app (accepted friendship,
  found by @username). Messages: text, a saved place, a 24-hour memory post.
- Sending a place from Khám phá, or sharing a memory for 24 hours (A10),
  puts a message in each recipient's conversation; they can reply there.
- No longer friends (or blocked): the history stays, read-only.
- Phase 1 has no push notifications: the app asks the server again every
  5 s while a conversation is open and every 30 s for the tab's unread
  count, only while the app is in front. Push (FCM/APNs) is phase 2.

## What the app does now

- `data/messages_repository.dart`: `MessagesRepository`;
  `RemoteMessagesRepository` calls the API below; `MockMessagesRepository`
  for tests. A route the server does not have (404/405) becomes
  `MessagesUnavailable`, and screens say "Tin nhắn sẽ mở khi máy chủ sẵn
  sàng" instead of an error.
- `messages_scope.dart`: `MessagesController` (unread count, polling, paused
  in the background), provided by `AuthGate` for signed-in accounts only.
  Guests see that messages need an account.
- `presentation/messages_screen.dart`: the tab (conversations newest first,
  unread counts, "Tin nhắn mới" → pick a friend).
- `presentation/chat_screen.dart`: bubbles, input (2,000 characters), a
  failed message stays marked and is sent again on tap with the same
  `client_id`; place and memory cards (an expired memory shows only that
  it expired); read-only notice.
- `presentation/send_place_sheet.dart`: Khám phá → a saved place → share →
  pick friends → `POST /place-shares`. The place's private note is never
  sent.
- Bạn bè AI-Journal: a "Nhắn tin" button on each accepted friend.

## API proposal (for Phúc; to be agreed and written into `docs/API_CONTRACT.md`)

All under `/api/v1`, authenticated; ids are UUIDs; times UTC RFC 3339.

Message object:

```json
{
  "id": "uuid", "conversation_id": "uuid", "sender_id": "uuid",
  "kind": "text | place | memory_share",
  "text": "≤ 2000 characters, kind text only",
  "place": {"name": "…", "latitude": 10.77, "longitude": 106.70,
            "category": "…?", "note": "…?"},
  "memory_share": {"share_id": "uuid", "title": "…?", "text": "…?",
                   "place_label": "…?", "expires_at": "…"},
  "client_id": "sender's idempotency key, echoed to the sender",
  "created_at": "…"
}
```

| Method and path | Contract |
| --- | --- |
| `GET /conversations` | Mine, newest activity first: `id`, `friend` (`user_id`, `display_name`, `username`), `last_message`, `unread_count`, `can_send` |
| `POST /conversations` `{"friend_id"}` | Get or create the one conversation with an accepted, unblocked friend; 403 otherwise |
| `GET /conversations/{id}/messages?after=&before=&limit=` | `{"items": [...]}` oldest first; `after` = newer than that message (polling), `before` = older page; limit 1–100, default 50 |
| `POST /conversations/{id}/messages` `{"client_id", "text"}` | Text only; same `client_id` from the same sender returns the existing message (no duplicate); 403 when `can_send` is false |
| `POST /conversations/{id}/read` `{"message_id"}` | Marks read up to it; returns `{"unread_count"}` |
| `GET /messages/unread-count` | `{"count"}` across all conversations |
| `POST /place-shares` `{"recipient_ids", "place"}` | 1–20 accepted friends; one `place` message each; returns `{"conversation_ids"}` |
| `POST /memory-shares` (PR #81 proposal) | Also adds one `memory_share` message per recipient, in the same transaction |

Rules:

- Only accepted, unblocked friends can open a conversation or send. Unfriend
  or block: `can_send` false, history kept for both, read-only.
- `memory_share` content is returned only while the share is active; after
  `expires_at` (or revoke) the message keeps only `share_id` and
  `expires_at`. Never the memory's private note.
- Rate limit sends (for example 30 messages a minute per sender).
- Deleting an account deletes its messages.
- Data policy (PR #76) must say messages are stored on the server.
