# Album

Personal scrapbook: albums, memories (photo, note or both), lock, and a
24-hour share to the map. Specs: A01–A12 and E05 in the UI/UX spec.

## Status

| Screen | State |
|---|---|
| A01 Album library | Built: `presentation/album_screen.dart` |
| A02 Create album | Built: `presentation/create_album_sheet.dart` |
| A03 Album settings | Built: `presentation/album_settings_screen.dart` |
| A04 Unlock | Built: `presentation/album_unlock_screen.dart` |
| A05 Start your memory album | Built: `presentation/album_start_screen.dart` |
| A06 Memory editor | Built: `presentation/memory_editor_screen.dart` |
| A07 Picker and replace | Built: `presentation/photo_picker_flow.dart` |
| A08 Memory detail | Built: `presentation/memory_detail_screen.dart` |
| A09 Scrapbook browse | Built: `presentation/album_browse_screen.dart` |
| A10 Share 24 h | Built: `presentation/share_memory_sheet.dart`; no share service yet (see below) |
| E05 Choose a place | Built: `explore/presentation/place_picker_screen.dart`, opened by `AlbumRoutes.pickPlace` |
| A11 Confirm delete | Built: `presentation/confirm_delete_dialog.dart`, `data/album_deletion.dart` |
| A12 Manage post | Built: `presentation/manage_post_screen.dart` (from A08) |
| E04 | Not built; a stand-in page |

## Data

- `data/album.dart`: `Album` (id, name, themeId, locked,
  hideNameWhenLocked, memoryCount, createdAt, updatedAt). Private by
  default; `locked` is an extra access check, not the same as private.
- `data/album_repository.dart`: `AlbumRepository` with a
  shared_preferences version (`LocalAlbumRepository`, key `album.albums`)
  and an in-memory one for tests. There is no album API yet
  (`docs/API_CONTRACT.md`); an API version implements the same interface.
  Names are trimmed, blank names refused; newest first, id breaks ties.
- `album_scope.dart`: provides repository, the albums' PIN lock
  (`AlbumAuth`, the app's `PinAlbumAuth` by default) and sharing adapter;
  `main.dart` provides the local repository.
- `data/album_unlocks.dart`: albums opened after authentication, in memory
  only. An album locks again when its last route closes (`AlbumRoutes`,
  after the exit animation; nested routes such as A03 → A11 keep it open)
  and everything locks when the app goes to the background. The OS PIN
  prompt pauses the app on Android; `duringSystemPrompt` keeps that from
  counting as leaving. The library always shows a locked album as locked.
- A02 with "Khóa album" on asks for the album's new PIN as it is turned on;
  giving up leaves it off. A03 returns to where it was opened from after a
  successful save, with "Đã lưu thay đổi.".

## Sharing with friends (30/10/2026: friends on the app, no Facebook)

Product decision (30/10/2026): Facebook is gone from the app (sign-in,
"bạn bè Facebook", the sample Space). Friends on the app are accepted
friendships between accounts, found by @username (`GET /friends`,
`GET /friends/discover`; Khám phá → Bạn bè). A 24-hour post is seen only by
the friends the user ticks in A10.

What the app does now:
- Signed in, A10 lists the account's accepted friends
  (`RemoteFriendsSharing`, `social/data/friends_sharing.dart`); all start
  ticked, as before. Pending requests are not friends and are not listed.
- With everything chosen the CTA stays off and says the server cannot
  send posts yet (`ShareMemorySheet.notDelivered`); nothing is posted and
  the choices stay. No friends: where to find them. Guests: none.
- `MockFriendsSharing` (in memory, this device only) keeps the picker and
  posting flow testable.

Not built on the server; a proposal for the backend owner, to be agreed and
written into `docs/API_CONTRACT.md` first. Today's `POST /memory-shares`
takes only cloud memories, returns the memory's private `note` to the
recipient, and recipients have no way to list what was shared with them.
- `POST /memory-shares`: the post's snapshot from A10, not the memory:
  `recipient_ids` (accepted, unblocked friends, 1–20), `title`, `text`
  (≤ 300), `place` (`label`, `latitude`, `longitude`), `category`, optional
  `replacing` (revoked in the same transaction); `memory_id` optional, so a
  memory kept only on the device can be shared. Expiry set by the server
  (+24 h). Photos later, with private photo storage.
- `GET /memory-shares/received` (optional bounding box): active posts shared
  with me by friends, with the author's display name and @username.
- `GET /memory-shares/mine?memory_id=…`: my active post for a memory (A10
  "replace", A12).
- `GET /memory-shares/{id}` must stop returning the memory's private `note`.
- A locked album is refused on the device (`withPublicationBlocked`); the
  server does not know album PINs.
- Then `RemoteFriendsSharing` sends instead of saying it cannot; nothing in
  A10's picker changes.

## Album PIN lock (27/10/2026, replaces the device lock)

- A locked album opens with a 4-digit PIN of its own, not the device's
  screen lock. `data/album_pins.dart` keeps only a salted hash (SHA-256,
  4,000 rounds, `crypto`) per album (`album.pin.<id>`); the PIN is never
  stored. `presentation/album_pin_sheet.dart`: `PinAlbumAuth` and the pad
  (`AlbumPinPad`) in the app's sheet: four dots, a round number pad,
  messages in the delete colour, reserved space so nothing jumps.
- Turning the lock on (A02, A03) asks for a PIN twice (a mismatch starts
  over); A03 applies it on "Lưu thay đổi", keeping the PIN before the album
  locks. Turning a saved lock off asks for its PIN first; the PIN is
  forgotten once the album is saved unlocked or deleted.
- A04 "Mở khóa" asks for the PIN; five wrong in a row wait 30 s (for the
  app session). "Quên mật khẩu?" says recovery by email will come with
  account sign-in: there is none yet (no login in the app, and no endpoint
  in `docs/API_CONTRACT.md`), so a forgotten PIN cannot be recovered today.
- Albums locked before PINs have none: the device's screen lock confirms
  the owner once (`local_auth`), a PIN is chosen, and it opens with that
  from then on.
- The lock still only gates opening the album in the app; it encrypts
  nothing, and a 4-digit hash on the device is not a vault.
- `memoryCount` is stored on the album until memories exist (A06).

## A02 create album

- Bottom sheet (Surface, top radius 28, 35 % overlay, slides in 300 ms;
  reduced motion: no slide), 78 % of the screen to start, drag to 95 %,
  scrolls; it shrinks above the keyboard and "Tạo album" stays visible.
- "Tên album": required after trimming, at most 60 characters with a
  counter; a blank name is said below the field ("Hãy đặt tên cho album.")
  and focuses it. Same names are allowed (different ids).
- "Bìa album": static preview cover (crossfades 180 ms) and a picker of six
  themes (`data/album_theme.dart`): Cổ điển (plain folder) and five supplied
  Nudaeng poses (Hoài nghi, Buồn, Ngại ngùng, Quàng khăn, Đọc sách) on a
  taped photo card. A theme only changes the pose and tape colour.
- "Khóa album": asks for the album's PIN as it is turned on (see "Album PIN
  lock"). The help text says the lock only gates opening the album in the
  app and encrypts nothing.
- "Tạo album": spinner in place while saving (same size, repeated taps
  ignored); a failure keeps the form and says so right above the button.
- Closing keeps the draft (name, theme, lock) for the app session
  (`CreateAlbumDraft.session`); nothing is created before the CTA. Success
  clears it, closes the sheet, and A01 takes over (new album at the top,
  "Đã tạo album" with "Thêm kỷ niệm", the new tile's glow). No celebration
  in the sheet itself.

## Device authentication setup (shared files, approved)

### Key animation in A04

- `presentation/nudaeng_album_key.dart`: `NudaengAlbumKey` holds a static key
  while `authSucceeded` is false. Set it true only after
  `AlbumAuthResult.success`: the key goes into the pouch once in exactly
  1 second, then the final pose holds and `onCompleted` fires once.
- Rebuilding with true does not replay. False resets/cancels; disposing
  cancels completion. Reduced motion shows the final pose immediately on
  success and completes after that frame.
- Four transparent `Deimage/album-key-frame-01…04.png` poses, 384×384 in
  the app (originals 1254×1254 in `tool/artwork_sources/album-key/`, scaled by
  `tool/build_album_layers.py`); timings 150 / 250 / 350 / 250 ms. Source
  and generation prompts are in `Deimage/album-key-assets.md`.
- A04 connects this presentation widget to device auth. The access guard
  grants access only after success, completion and a valid foreground session.

## A03 settings and A04 unlock

Layout (shared with A02 through `presentation/album_form_parts.dart`):
paper sections, the cover preview on mint (crossfade 180 ms), the 3 × 2 theme
grid with thumbnails (`AlbumCoverThumbnail`), the lock card (switch, the
saved state as "Hiện tại: Đang khóa / Chưa khóa" with an icon, and "Khóa chỉ
chặn việc mở album trong app, không mã hóa ảnh và ghi chú."), messages next
to their action. A03's "Xóa album" is an outlined button in the theme's
error colour, apart from the rest, never the primary. A04: generic locked
cover with Nudaeng (96) holding the key beside it on a paper card, the state
as text and icon in a pill (never the mascot alone), "Mở khóa" / "Thử lại",
"Hủy". Forms build every section (no lazy list), so the lock card can be
reached by scrolling and by screen readers.

- A03 edits name, cover/theme and desired lock. Save is disabled when unchanged
  or invalid. Actual lock status is shown separately from the draft toggle.
  Themes affect only the cover, not navigation, CTA or typography.
- Back keeps the draft in memory for this app session, including after a
  background relock. Drafts do not survive process termination. Saving patches
  only name, theme and lock in raw JSON, preserving IDs, dates, memory fields
  and ordering. Serialized writes prevent competing local updates being lost;
  reads expose only acknowledged writes, not SharedPreferences' optimistic cache.
- Lock on asks for a new PIN, lock off for the current one. Active shares require explicit
  “Thu hồi bài chia sẻ và khóa album” consent. The writer checks shares, revokes,
  verifies no active shares remain, then saves the lock. Errors retain the draft
  and provide Retry; if revocation succeeds but saving fails, it says so.
- **Integration boundary:** `AlbumSharing` is injectable. The current app has
  no publishing API and Explore sharing is a mock, so `NoAlbumPublishing` is
  the default. A real adapter must enforce a server-side publication barrier
  across revocation, verification and the lock write. Do not use the no-op
  adapter for real public posts. No backend contract was changed.
- Delete is a separate action leading to A11 (below).
- A04 shows only a generic locked cover and copy; no private name or preview.
  Nudaeng is 96 logical pixels, static while waiting. Success plays ND13 once
  for 1 second (immediate final pose for reduced motion). Text/icon communicate
  status independently. Failure/cancel leaves the mascot neutral; Cancel
  returns to the source. Asks for the album's own PIN (since 27/10/2026).
- `AlbumAccessGuard` covers every destination, including direct A03/A08 opens.
  It retains the pending route, memory ID and mounted editor while private UI
  is offstage (also excluded from semantics). Paused/hidden/detached invalidate
  the session; inactive system overlays hide content without abandoning work.
  Resume checks the session before revealing content. Device auth persists
  across background interruptions; a stale success animation cannot unlock.
- A05/A08/A09 remain guarded stand-ins. Picker return behavior is supported by
  the guard's retained route/draft, but there is no album picker screen yet.
  Native auth/picker lifecycle still needs verification on physical iOS/Android.

### Validation

`flutter test --no-pub test/features/album` covers settings preservation,
revocation/write failures and Retry, authentication outcomes, pending routes,
background/overlay transitions, ND13 timing, draft retention and large text.
`flutter analyze --no-pub lib/features/album test/features/album` checks this feature.

### Platform configuration

- `pubspec.yaml`: `local_auth`.
- Android: `MainActivity` is a `FlutterFragmentActivity`, the manifest asks
  for `USE_BIOMETRIC`, and `LaunchTheme` inherits `Theme.AppCompat` (light
  and night), as `local_auth_android` requires.

## A10 share a memory for 24 hours

- Data (`data/memory_share.dart`): `SharePayload` (album, memory, audience,
  place, category?, title?, photoPath?, text?) is exactly what is posted;
  `SharedMemoryPost` adds the post id and the server's `expiresAt`.
  `MemorySharing` (in `AlbumScope.memorySharing`) lists audiences, gives a
  memory's active post and publishes. `NoAlbumPublishing` is the default:
  no audiences, and a publish throws `ShareUnavailable`, so the app never
  says something was shared. There is no share API in
  `docs/API_CONTRACT.md` yet; nothing in the contract was changed.
- Sheet from A08 "Chia sẻ trong 24 giờ" (not offered for a locked album):
  solid Surface, 35 % dim, 300 ms, 88 % of the screen to start, up to 95 %;
  the form scrolls, the CTA is docked. Order: "Chia sẻ kỷ niệm trong 24 giờ"
  and Close; "Bản xem trước" (photo whole, title, the post's text, place and
  category chips, as posted); "Ai sẽ thấy bài này" (names from the service,
  none chosen by default); "Địa điểm" ("Dùng địa điểm của kỷ niệm" when the
  memory has one, "Chọn địa điểm" → E05; never the device's location);
  "Phân loại" (Ăn uống / Giải trí / Cà phê học bài = Food / Entertainment /
  Study Cafe; none is "Chưa phân loại"); "Mô tả chia sẻ" (empty, at most
  300 characters); the 24-hour line; the CTA.
- The private note is never copied in. "Chọn một đoạn từ ghi chú" shows it
  (marked private) to select a passage and "Thêm đoạn đã chọn". Photo
  memories can post the photo alone; note-only ones need text.
- CTA enabled only with a listed audience, a confirmed place and something
  to show; otherwise the line above it says what is missing (at the end of
  the form with large text). Opening the sheet, choosing a place or closing
  posts nothing; Close keeps the choices for the session
  (`MemoryShareDraft`, per memory, apart from the memory and its A06 draft).
- Publishing: spinner in the CTA, repeated taps ignored, Close, Back and
  drag off, form kept. The album is read again first: locked → nothing is
  posted. Failure: the message by the CTA and "Thử lại". Success: a check
  (180 ms), "Đã chia sẻ trong 24 giờ" and the server's expiry for 900 ms;
  the draft is cleared, the album routes close, `AlbumRoutes.published`
  carries the post to A01, which hands it to the app shell: Explore (E01)
  opens with the pin larger than the others, the camera on it (set at once
  with reduced motion) and its card open (title, text, place, expiry). The
  pin is shown until `expiresAt`.
- Re-share: a memory has one active post. Then the sheet says that sharing
  again takes that post down and the new one expires 24 hours later;
  publish passes `replacing:` and success says "Đã thay bài chia sẻ cũ bằng
  bài mới". Editing the memory or reopening the sheet changes no post and
  no expiry.
- No mascot in the sheet; the success is a check and text.
- The sheet hides behind system overlays and in the app switcher, as album
  routes do (`AlbumUnlocks.foreground`).
- The shell keeps only the latest post's pin in memory (no list of posts).

## A11 confirm delete

- `ConfirmDeleteDialog`: the app's shared delete dialog
  (`core/widgets/app_delete_dialog.dart`, also used for journal entries):
  Nudaeng crumbling away, centered title "Xóa kỷ niệm?" / "Xóa album?",
  what goes (memory title and album name; an album's memory count; a
  locked album that hides its name is called "Album đã khóa"), that posts
  are taken off the map, "Không thể hoàn tác." (no undo is offered).
  "Giữ lại" on light grey and the action ("Xóa kỷ niệm" / "Xóa album") in
  brick red (`AppDeleteDialog.destructive`), never the primary teal.
- The deletion runs in the dialog: spinner in the button, repeated taps,
  "Giữ lại", Back and the barrier off. Failure: the dialog stays, says what
  happened and "Thử lại"; nothing is removed from screen.
- `AlbumDeletion` (data): a memory's active post is revoked and confirmed
  gone, then the memory (with its place) is removed in one write; an album
  is deleted inside `withPublicationBlocked`: `revokeAll`, check none is
  left, then the album and all its memories. A post that cannot be revoked
  stops the deletion. Afterwards (best effort) the app's photo copies are
  removed (`MemoryPhotoCleanup`, only files under `album_photos/`), and the
  editor, share and settings drafts are forgotten.
- After success only: A08 (memory) or A03 (album) fades out in 180 ms
  (reduced motion: at once), then A08 closes to where it was opened (A09
  without that card, A05 when it was the last) or the album closes to A01.
  `AlbumAccessGuard.departing` keeps a deleted album's screens as they were
  while they leave (no "Album không còn tồn tại." flash). No animation of
  joy. `AlbumRoutes.unshared` tells the shell, which drops the post's pin
  from E01.
- Albums are deleted with their memories; keeping memories would need a
  step to pick another album (not offered).

## A12 manage a post

- A08 shows "Đang chia sẻ đến HH:mm, dd/mm/yyyy" (icon and text, no
  countdown) with "Quản lý bài chia sẻ" while the memory's post is active
  (asked again when the app comes back). That opens A12 (guarded, over A08).
- A12: the state as text and icon (Đang chia sẻ / Đã hết hạn / Đã gỡ khỏi
  bản đồ / Không còn trên bản đồ), when it ends or ended, the snapshot as
  posted (A10's `SharePreview`), audience, place. No mascot.
- The state comes from `MemorySharing.post`: on open, when the app comes
  back, and once at the expiry time (one timer, not a ticking one). A failed
  refresh keeps the last state and says so, with "Thử lại".
- Active: "Gỡ khỏi bản đồ" (error colour) → the same dialog ("Gỡ bài khỏi
  bản đồ?", the memory, photo and private place stay) → `revoke` → back to
  A08 with "Đã gỡ bài khỏi bản đồ. Kỷ niệm vẫn ở Album."; the pin leaves
  E01. Expired or revoked: "Chia sẻ lại" opens A10 (posts nothing by
  itself); a locked album says why it cannot. "Về kỷ niệm gốc" → A08.
- Public thumbnails after expiry are the server's to withhold; the app
  shows the owner's own snapshot here and drops the E01 pin at `expiresAt`.

## E05 choose a place (from A06 and A10)

- `AlbumRoutes.pickPlace(context, album, current:)` opens
  `PlacePickerScreen` (in `features/explore`, it imports nothing from
  Album) inside `AlbumAccessGuard`, so it hides in the background and asks
  A04 again for a locked album. It returns a `MemoryPlace`, or null to keep
  `current`. Nothing is saved or posted: A06 saves with "Lưu kỷ niệm", A10
  shows the place in the preview and posts only with its CTA.
- Screen: Explore's MapLibre style full screen (no Album scene), Back and
  "Tìm địa điểm" on Surface at the top, results on Surface below, a pin
  fixed at the centre (Primary with an ink outline, faded until something
  is chosen), and a Surface panel: name, address or "Địa điểm mẫu",
  coordinates, "Dùng địa điểm này". No mascot.
- Pick by search (300 ms debounce; an older answer never replaces a newer
  query's), by dragging the map under the pin (the camera stopping after a
  touch picks the point) or by tapping a point (the camera moves there).
  Camera moves 300 ms; reduced motion: set directly.
- A pin is looked up for a name (`PlaceLookup.nameAt`). States: looking
  (CTA waits), named, nothing named there, lookup failed. The last two say
  so, differently, and keep the coordinates usable with an optional "Tên địa
  điểm". Unnamed places become `MemoryPlace(named: false)` with the label
  "Vị trí chưa có tên (lat, lng)"; A10 adds that viewers will see it so.
- `MemoryPlace` gained `named`, `address` and `placeId` (search id); places
  stored before have only label and coordinates and read as named.
- Sources today: search is Explore's demo places (`MockPlaceLookup`, marked
  "Địa điểm mẫu"); there is no name lookup service (the API contract has no
  reverse geocoding), so every pin says the lookup failed.
- "Vị trí của tôi": `DeviceLocation`, asked only after the tap, and the
  position is a candidate like any other (still needs "Dùng địa điểm này").
  The default `NoDeviceLocation` hides the button: the app has no location
  plugin or location permission yet (needs `pubspec.yaml` and the Android
  manifest, shared files).

## A09 scrapbook pile and grid

- Back, the album name (kept current) and "Cài đặt album" (A03); "+ Thêm kỷ
  niệm" (A06) docked at the bottom, the pile ending above it; "N kỷ niệm"
  with a small still Nudaeng when there is room.
- Each memory on ivory paper, no border. The date small on top ("28 tháng
  10, 2026"), the photo at its own proportions (never cropped beyond
  0.6–2:1) with its height giving way so the title (2 lines) and note (3
  lines) always show, left aligned. Note-only memories are a text card only
  as tall as its words. One strip of tape over the top edge (cream, mint or
  striped, the same for a memory each time) and a small Nudaeng sticker off
  the bottom corner, never over the words. Tap the top one → A08.
- A pile of photos on a table: the memory shown on top, the next two under
  it, each a little lower, off to one side and turned (±3°, the same for a
  memory each time; the top one only a quarter of that). No gap between
  them; what shows of the ones under says there are more.
- Pick up the top photo and drag it anywhere: it follows the finger, turns
  with where it was gripped (above or below the middle) and lifts (scale
  1.03, a larger and softer shadow). Let go past 30 % of its width, or throw
  it (900 px/s the way it was moving): it flies off, turning over to show
  the back of the paper, and the ones under it move up. Otherwise it settles
  back (a small overshoot). Pull down instead: the previous photo comes down
  from above face down and turns over as it lands (past 30 % of the room or
  700 px/s), else goes back up. The last photo, and a pull down on the
  first, only give a little.
- Each turn plays the interface's page-turn sound (`SoundCue.pageTurn`, so it
  follows the sound settings) with a light haptic tap, once, when the finger
  lifts. A drag that settles back, or the app moving the pile itself (a
  memory added before it), is silent.
- Reduced motion: no flying or turning over; the change is at once. Screen
  readers get "Kỷ niệm tiếp theo" / "Kỷ niệm trước" custom actions. Only a
  small "02 / 03" under the pile (read out as "Kỷ niệm 2 trên 3").
- "Xem tất cả": a grid by month (two columns: photo or note, title, date),
  20 at a time with "Xem thêm kỷ niệm". "Xấp ảnh" goes back to the photo
  that was on top.
- Artwork: `assets/images/scrapbook/` (tapes, Nudaeng hugging a photo),
  decoded at a small size (`cacheWidth`).
- Order from the repository: memory date, then creation, then id, newest
  first. Back from A08 keeps the card (by id), the mode and the list scroll.
- A05 and A09 share one route: an empty album shows A05, one with memories
  A09, and it switches when that changes.

## A08 memory detail

- Back and "More" (Sửa kỷ niệm → A06 with the id; Xóa kỷ niệm → A11 dialog). Paper
  over the Album scene: date chip, place chip (→ E04), title in the display
  font when there is one, the photo whole (its own proportions, `contain`,
  capped at 70 % of the screen; nothing drawn on it), the note in the body
  font, "Chia sẻ trong 24 giờ" (→ A10). A locked album shows why sharing is
  off instead; nothing unlocks to publish.
- Note-only: a small tape strip on the paper, no photo placeholder. The page
  scrolls; long notes are never cut into a fixed card. A photo that cannot be
  opened says so; the note still reads.
- ND11: "Chú chó ôm sách đầy yêu thương" (Nudaeng closes the book and hugs
  it; 9 × 180 ms) at 88 dp in the header corner, outside the reading card.
  Plays once right after a save (new: A08 replaces the editor; edit: the
  editor returns to this same A08, which updates); reopening shows the last
  pose still. Card entrance 320 ms (16 dp rise and fade); reduced motion: fade.
- Back after the first memory of an album shows A09 (A05 turns into A09).

## A07 photo picker and replace

- With a camera (`MemoryPhotos.hasCamera`), a sheet offers "Chọn từ thư
  viện" / "Chụp ảnh" / "Hủy"; without one the system photo picker opens
  directly. Nothing is opened or asked before a tap. The camera is the
  system camera app; the manifest declares no CAMERA permission, so no
  prompt is needed (access refused → `PhotoAccessDenied`).
- Preview: the photo in its own colours on a dark neutral ground, "Dùng ảnh"
  or "Hủy"; only "Dùng ảnh" changes the memory, so canceling a replace keeps
  the old photo. A file that cannot be previewed disables "Dùng ảnh".
- Refused access: a message under the photo slot, once (no popup loop); the
  note still saves. There is no "Mở cài đặt" button: opening the app's
  settings needs a plugin or native code not in the project yet.
- After "Dùng ảnh" the copy is kept (loading state), then the photo fades in
  (180 ms, nothing else moves); never after a cancel. The
  picker and camera run inside `AlbumUnlocks.duringSystemPrompt`, so the
  album being edited does not lock behind them.

## A06 memory editor

- Data (`data/memory.dart`): `Memory` (id, albumId, content, createdAt,
  updatedAt), `MemoryContent` (title?, note?, photoPath?, displayDate,
  place?), `MemoryDraft`. Memories live inside their album's stored record,
  so a new memory and the album's count change in one write; `update()` and
  `updateSettings()` keep them. Valid with a photo or a non-blank note.
- Photos (`data/memory_photos.dart`, `image_picker` + `path_provider`): the
  system picker only when the photo slot is tapped, then a copy in the app's
  documents (`album_photos/`), never the picker's temporary file.
- Screen: "Kỷ niệm mới" / "Chỉnh sửa kỷ niệm"; paper (radius 20, padding 20)
  over the Album scene (dimmed while typing); optional title; 4:3 photo slot
  (empty: "Thêm ảnh"; loading; failed: Retry / Remove; ready: photo with "Thay
  ảnh / Xóa ảnh"); "Ghi chú về kỷ niệm" typed in place, 16/24 over faint
  ruled lines; date (dd/mm/yyyy, separate from created/updated); "Thêm địa
  điểm" (E05); draft status; "Lưu kỷ niệm" sticky above the keyboard.
- Saving: one at a time (repeated taps, one memory); waits while the photo
  loads or has failed; a failure keeps text and photo. Create → A08 in the
  editor's place; edit keeps the id and creation time. Draft 800 ms after
  the last change; Back keeps it, and when it cannot be kept asks "Tiếp tục
  viết / Thử lưu / Bỏ thay đổi". A05 shows A09 once the album has a memory.
- Nudaeng: ND09 (`album-write-frame-01…06`, about 1 s) in the header
  corner on the first note focus, then gone. ND08 (the head turn below a new
  photo) was dropped on 27/10/2026. ND11 belongs to A08 (not built).
- The photo's "…" opens the app's sheet ("Ảnh của kỷ niệm": "Thay ảnh",
  "Xóa ảnh" in the delete colour), as Home's actions, instead of a popup
  menu.
- The date picker's month names follow the app locale (English until
  `flutter_localizations` is set up).

## A05 start your memory album

- Back and the album name; one paper sheet over the Album scene
  (`album_backdrop.dart`, shared with A01, no background Nudaeng next to
  the hero).
- Hero: " Nudaeng long lanh.gif" as a taped photo, 176 → 128 (at most about
  a third of the screen; 128 with large text), the page scrolls when short.
  The GIF loops every 160 ms and has no head tilt or blink, so A05 plays it
  as: settle 250 ms, tail wags at the GIF's own pace, back to the first pose
  by 1.75 s, then still. Once per album per session; returning from A06/A07
  or reopening shows it still; reduced motion: still. The whole picture is
  kept (the big face behind shares Nudaeng's beige), not cut out.
- "Bắt đầu album kỷ niệm của bạn", the description, "Thêm kỷ niệm đầu tiên"
  (16 below the text) and "Viết note trước" (12 below), caption "Scrapbook
  sẽ mở sau kỷ niệm đầu tiên". The CTAs work while the hero still moves.
- Primary → A06 photo-first, note → A06 note-first (`MemoryStartIntent`);
  nothing here asks for photo access. Back → A01.

## A01 library

- Title "Kỷ niệm" (the tab name; shared `AppPageHeader`), subtitle "Giữ lại những điều bạn muốn nhớ.", two-column
  grid (gap 16, padding 20; tiles grow with two-line names, three at large
  text), "Tạo album" docked above the bottom navigation; the last row always
  scrolls clear of the dock.
- Tile: Surface card, folder cover (`album_cover.dart`), name, memory count
  when there is one. Locked: generic cover with a lock, "Đã khóa", no count;
  "Album đã khóa" instead of the name when `hideNameWhenLocked`.
- Tap: empty → A05, with memories → A09, locked and not unlocked → A04 with
  the destination. Menu button (own 48 × 48 target) or long press → A03, or
  A04 first when locked.
- States: skeleton on first load; a failed first load says so with "Thử
  lại" (never shown as an empty library); a failed refresh keeps the albums
  shown with a notice. No album: one group a little above the middle (it
  scrolls when space is short): the first page of a scrapbook (ivory paper,
  two small white frames with a drawn sky and a drawn flower, never anything
  like a user's photo; a mint and a striped strip of tape; Nudaeng hugging a
  photo in the corner), "Những điều nhỏ, đáng nhớ", one line of invitation
  and "+ Tạo album đầu tiên" right under it. The dock is hidden then, so the
  button stays with its words. An album with no memory yet has its own page
  (A05).
- Background: teal-mint sky in theme colours (falls back to Background
  Mint). The floating Nudaeng of "Background 2" shows faintly only while
  there are one or two albums.
- After creating: the new tile fades in (200 ms) at the top, a snack bar
  floating above the dock offers "Thêm kỷ niệm" (→ A05), and the tile
  carries a teal outline and soft glow that fade away (1.8 s in all), once,
  until the user leaves the library. No Nudaeng over the grid (the peek
  behind the cover was dropped: it was cut by the tile's edge). Reduced
  motion: there at once, no glow.
- `AlbumScreen.onShare` receives the post made in A10 (via
  `AlbumRoutes.published`) and the app shell opens Explore with it; the demo
  Share card and the shell's mock Share dialog are gone
  (`test/explore_share_test.dart` posts through `AlbumRoutes.published`).

## Artwork (`tool/build_album_layers.py`)

- `album-peek-frame-01…08.png`: "Chó hoạt hình quay đầu đáng yêu.gif",
  grey backdrop removed, one shared crop (404 × 371).
- `album-bg-nudaeng.png`: Nudaeng from "Background 2.png" without the slate
  frame and cyan square; the app paints the sky.
- `album-empty-nudaeng.png`: first frame of "Chú chó ôm sách đầy yêu
  thương-transparent.gif" (no longer shown on A01; A01's empty page uses
  `images/scrapbook/nudaeng-hugging-photo.png`).
- `album-theme-<id>.png`: theme poses from
  `tool/artwork_sources/album-themes/` (copied from the supplied Nudaeng
  images), backdrop and copyright line removed, at most 360 px.
