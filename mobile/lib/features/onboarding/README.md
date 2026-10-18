# Onboarding

Flow OB01 → OB11 → Home. Entry: `OnboardingFlow` (`onboarding_flow.dart`).

Run with onboarding as the launch screen:

```bash
flutter run --dart-define=ONBOARDING=true
```

Without it the app opens Home as before. OB11 now completes the flow;
making onboarding the default launch is a separate decision (`lib/main.dart`).

To test the flow from OB01 on every launch and hot restart:

```bash
flutter run --dart-define=ONBOARDING_RESET=true
```

It clears every `onboarding.*` key and the OB07 draft; saved journal
entries stay (they are journal data, and a new run saves a new entry).

## Status

| Screen | State |
|---|---|
| OB01 Welcome | Built: `presentation/onboarding_welcome_screen.dart` |
| OB02 Nickname | Built: `presentation/onboarding_nickname_screen.dart` |
| OB03 Purpose | Built: `presentation/onboarding_purpose_screen.dart` |
| OB04 Experience | Built: `presentation/onboarding_experience_screen.dart` |
| OB05 Features | Built: `presentation/onboarding_features_screen.dart` |
| OB06 AI and data | Built: `presentation/onboarding_ai_data_screen.dart` |
| OB07 First entry | Built: `presentation/onboarding_first_entry_screen.dart` |
| OB08 Preparing | Built: `presentation/onboarding_preparing_screen.dart` |
| OB09 Entry saved | Built: `presentation/onboarding_entry_saved_screen.dart` |
| OB10 Reminders | Built: `presentation/onboarding_reminder_screen.dart` |
| OB11 Ready | Built: `presentation/onboarding_ready_screen.dart` |

## State (`data/onboarding_store.dart`, shared_preferences)

- `onboarding.step`: route to resume. Saved on every route change; "Bắt đầu"
  starts the session at OB02, Back saves the previous route.
- `onboarding.nickname`: trimmed OB02 nickname, saved on "Tiếp tục" before
  moving to OB03; absent when left empty (later copy says "bạn"). The text
  being typed is kept in memory across Back, not across an app restart.
- `onboarding.goal`: OB03 `JournalGoal` name (`data/journal_goal.dart`), saved
  on "Tiếp tục"; removed by "Để sau". Only for topic/prompt suggestions where
  an editorial mapping exists; never a diagnosis or personality score.
  Changing it touches nothing else (entries and drafts stay).
- `onboarding.experience`: OB04 `JournalingExperience` name
  (`data/journaling_experience.dart`): `beginner`, `occasional`, `regular`,
  or `unknown` after "Để sau". Absent until OB04 is answered.
- `onboarding.ai`: OB06 choice, `on` or `off`; absent until one of the two
  paths is taken (Back is not a choice). AI only: not marketing consent,
  notification permission or Album publishing.
- `onboarding.aiPolicyVersion`: policy version the AI choice was made under;
  written only when the policy has one (none yet), cleared when AI is off.
- `onboarding.firstEntryId`: id of the entry saved in OB07; Back to OB07
  then edits that entry instead of creating another.
- `onboarding.reminders`: OB10 reminders the OS actually accepted, as
  `slot@HH:mm` (`morning@08:00`); empty after "Tiếp tục không nhắc", a
  refused permission or "Tiếp tục" past a failure. "Để sau" leaves it as it
  was. The OB10 draft is never stored (memory only, kept across Back).
- `onboarding.completed`: launch goes to Home. Only OB11 calls `complete()`,
  which also clears the saved route. It throws when "done" could not be
  written; the route then stays OB11, so nothing is asked again.

To see OB01 again on a device: go Back to OB01, or clear the app's storage.

## OB01 scene

| Layer | Asset | Placement / motion |
|---|---|---|
| Background | `Deimage/nudaeng-mint-background.png` | Covers the screen, anchored to the bottom. Static |
| Nudaeng + umbrella | `Deimage/nudaeng-umbrella-frame-01…04.png` | Whole figure in the space between the text and the CTA, feet just above the CTA, soft ground shadow. Blinks on entry (800 / 100 / 120 / 780 ms), then again after a random pause, about every 3–6 s (`nudaeng_umbrella_blink.dart`) |
| Petals | `Deimage/nudaeng-mint-petal.png` | 7 petals around Nudaeng, staggered, 8–12 s per fall (`falling_petals.dart`) |

- Fitting uses the frames' visible bounds (31, 33)–(1055, 1418) of 1083×1453,
  so the transparent margin never pushes Nudaeng off screen.
- The CTA floats over the background with no band or fade. Text sits on a
  light veil only and uses the darkest text colours over the clouds.
- CTA and brand use `AppColors.primaryAction` (`#2E6E78`, white label 5.1:1, AA).
- Reduced motion: frame 01, no blinking, no petals.
- Short screen / large text: Nudaeng shrinks to 128 high and the content
  scrolls; font size never shrinks.
- The supplied frames are a blink only. The brief's "look up at the petals,
  turn the head towards the viewer" needs extra head-turn frames.
- `Nudaeng dưới tán hoa bạc hà.png` is the source composite; the app no
  longer uses it.

## OB01 → OB02 transition

Run by `OnboardingFlow` on "Bắt đầu" (gust 1.6 s, `PetalGust.duration`):

1. The route is saved at once (closing the app mid-way resumes at OB02);
   extra taps are ignored.
2. 0–~550 ms: the OB01 petals are carried off to the right and up, spinning
   (`FallingPetals.gust`), while a gust of 18 petals enters from the left
   over the whole screen (`PetalGust`).
3. ~550 ms: OB02 replaces OB01 (fades in over it in 280 ms; OB01 stays opaque underneath, every step change does the same); the gust keeps crossing.
4. OB02 parts appear one after another (`OnboardingStagger` / `StaggerItem`:
   80 ms delay, 90 ms apart, 380 ms each): eyebrow, title, field,
   helper, Nudaeng, CTA. Input works throughout.

Back to OB01 stops the gust so its petals fall normally again. Reduced
motion: no gust, no stagger, 120 ms fade.

## OB02 nickname

- Rules in `data/nickname.dart`: trim both ends, any Unicode allowed, max 30
  grapheme clusters (a letter with its marks or one emoji counts once). Over
  the limit the text is never cut: a message replaces the helper and
  "Tiếp tục" is disabled until it is fixed.
- No autofocus; the keyboard opens on tap. Done only closes the keyboard.
- Nudaeng: `Deimage/nudaeng-cockroach-frame-01…12.png`, played on entry,
  then again after 6–10 s (`nudaeng_chasing_cockroach.dart`). The run keeps
  the source pace (170 ms) and slows over the last three frames (200 / 240 /
  300 ms, ≈ 2.3 s in all), then hands over to the idle at once.
- Idle between runs (`nudaeng_cockroach_idle.dart`), mounted from the start
  so it is decoded before it shows. It begins as exactly the run's last frame
  split in two (`nudaeng-cockroach-rest-dog.png`, `…-rest-cockroach.png`,
  motion marks removed), so the swap is instant and invisible: no crossfade,
  which used to dim Nudaeng for a moment. The twitching cockroach sprite
  (`ob02-cockroach-idle-01…03.png`) then fades in over the still-opaque run
  cockroach (260 ms); after a 1.2–2 s breath its antennae twitch (left 200 ms
  → centre 120 ms → right 200 ms → centre), again every 2–4 s. Sprites decode
  at display size.
- Sized, placed and breathing via `OnboardingMascot` (below). Hidden while
  the keyboard is open. Reduced motion: idle pose, still.
- Frames are cut from `NudaenggifDe/Chú chó đuổi bắt gián hoạt hình.gif` by
  `tool/build_cockroach_frames.py` (grey backdrop removed, cockroach kept,
  soft alpha on the outline). GIF transparency is 1-bit, so PNG frames are
  used instead of a transparent GIF.
- The script also splits frame 12 into `nudaeng-cockroach-rest-dog.png` and
  `nudaeng-cockroach-rest-cockroach.png` (largest and second-largest shape).
- `tool/build_cockroach_idle_frames.py` builds the three idle cockroach PNGs
  directly from that same GIF frame on the same 306×319 canvas. The neutral
  sprite is pixel-identical to the run's cockroach cutout. Only the antenna
  tips above y=249 move (up to 2 px left/right); body, face, wings and feet
  remain identical across all three poses. No AI redraw or separate scaling
  is used for the cockroach (`Deimage/ob02-idle-assets.md`).

## OB03 purpose

- Eyebrow greets the saved nickname, or "bạn". Five single-choice cards
  (Surface, min 64 high, radius 20, padding 16, gap 12); the whole card is
  the hit area, radio on the right, label wraps. Selected: Primary Light
  fill, 2 px border and a filled radio in Primary Action, semibold label, so
  it is not colour alone (Primary on Primary Light is under 3:1). Exposed to
  screen readers as checked items in a mutually exclusive group.
- Picking only updates the selection; "Tiếp tục" is enabled once something
  is picked. "Để sau" moves on with no goal. "Một lý do khác" asks for no
  free text. The choice survives Back.
- Nudaeng: `Deimage/Nudaeng gãy đàn.png` under the list, sized and placed by
  `OnboardingMascot` (below); hidden when the list needs the room. The gap
  between the helper and the list is 16 so it still fits on 430×932.

## OB04 experience

- Title only, then three `OnboardingOptionCard`s (the OB03 component) with
  a description line. "Tiếp tục" needs a choice; "Để sau" saves `unknown`.
  The choice survives Back; a saved `unknown` shows nothing selected.
- On a selected card the description switches to Text Primary: Text
  Secondary on Primary Light is under 4.5:1.
- Personalisation is documented on the enum for OB07 and later (beginner:
  clearer hints; occasional: mention a draft can be resumed; regular: fewer
  hints). It never locks methods or changes AI quality; without an edited
  prompt mapping, the default edited prompt is used, and loading never
  claims "AI just personalised this". Not wired yet: OB07 is not built.
- Nudaeng: `Deimage/Nudaeng quàng khăn-transparent.png`, cut from
  `Nudaeng quàng khăn.jpg` by `tool/strip_nudaeng_backgrounds.py` (head 3,
  feet (223, 532) of 435×536).

## OB05 features

- Title, then up to three read-only cards (one outline icon set: lightbulb,
  chat bubble, photo library; title 17 semibold, body 14/20). Nothing moves
  on by itself (no timer, no carousel). "Xem cách hoạt động" → OB06.
- Each card has a flag in `data/build_features.dart`, so the copy follows
  the build. Today: prompts on (local samples), AI reflection on (the flow
  exists; the API is not wired yet), Album on by product decision
  (16/10/2026) although the screen is still empty. The extra Study/places
  line needs `study && places`; Explore is still empty, so it is hidden.
- Nudaeng: `Deimage/Nudaeng xem hướng dẫn-transparent.png`, cut from
  `Nudaeng xem hướng dẫn.png` with `strip_nudaeng_backgrounds.cutout`, which
  keeps the largest shape: the desk, clock, notebook and phone are joined to
  Nudaeng; the "©Nudaeng." signature is dropped (team-owned art, confirmed
  16/10/2026). Seated, so the scene is 120 high (head the same size as the
  standing poses at 96); same feet line and centre. Title → cards gap 16 so
  it fits on 390×844; hidden on 360×800 and smaller.

## OB06 AI and data

- Explains how AI and data work, before anything is sent: three sections in
  one Surface card (Nhật ký của bạn / Khi yêu cầu phản hồi AI / Quyền lựa
  chọn), body 16/24. Two explicit paths, no pre-set toggle: "Tiếp tục với
  AI" (AI on) or "Chỉ viết nhật ký" (AI off), both → OB07. Nothing calls AI
  from this screen.
- All data copy comes from `data/data_policy.dart` (`DataPolicy.current`),
  which only the product team edits with wording that matches the real
  architecture. Nothing is approved yet: the build stores no entries and AI
  is the deterministic mock (ADR-005), so the copy says exactly that under a
  "Bản thử nghiệm: phản hồi AI là mô phỏng" label. No "on-device only",
  "encrypted" or "never used for training" claims; tests guard this.
- "Cách app dùng dữ liệu" shows only when `policyUrl` is set (never a fake
  link). Opening a real page needs `url_launcher` (not in pubspec) or an
  in-app policy page.
- To do with OB07–OB09: keep the storage copy in step with where the first
  entry is really saved; honour `aiEnabled` before every request (AI off:
  no raw text sent, nothing queued, no automatic retry); on a switch from
  on to off, stop new requests, cancel the one in flight if the service
  allows, and ignore late responses. The new choice applies to later
  requests only; it cannot recall what was already sent.
- Nudaeng: `Deimage/Nudaeng xé-transparent.png`, the OB05 desk with
  Nudaeng tearing a note. Both desk scenes share one crop (`deskScene`, box
  (119, 176, 637, 666) of the 736 px sources, "©Nudaeng." dropped), so the
  desk stays put between OB05 and OB06 and only the pose changes. Kept at
  the OB05 size (120) instead of the brief's 88–96 for that reason.

## OB07 first entry

- Writes to the shared journal store (`features/journal/data/`), no
  separate onboarding store. `JournalScope` (set in `main.dart`) hands the
  same `JournalRepository` to Home, the J01 editor and onboarding.
- Guided body: `GuidedTemplate.firstEntry` (`onboarding_first_entry` v1),
  four sentences, one per block: mood (sheet, single choice from
  `JournalMood`, can stay empty; self-reported, never AI) and three text
  blanks (multiline sheet: title, field label, "Dùng nội dung này", Close).
  Confirm updates the blank; Close keeps the old value; unconfirmed typing
  stays per blank for the session. Blanks wrap inside the paper, at least
  48 high; from ~1.4× text they become labelled field blocks, same order.
- Save needs one non-blank text field (a mood alone is not enough); no
  minimum length. Saved: structured values (only filled blanks), template
  id + version, mood, a readable body rendered from the filled blanks only,
  and `bodyVersion` (1, +1 on each content change).
- Draft autosaves 800 ms after a change to the same store
  (`journal.draft.onboarding.first_entry`), labelled "Bản nháp đã được
  giữ"; never listed as an entry, cleared after a successful save.
- Save: "Đang lưu nhật ký của bạn…" at once (nothing says saved yet),
  repeated taps ignored; success gives the entry id → OB08 if AI is on and
  a reflection is running, else OB09. Back during a save does not cancel
  it: it finishes inside `FirstEntrySession` (owned by the flow), the step
  does not jump, and OB07 then offers "Tiếp tục" on that entry. Failure stays with the text, message +
  "Thử lại" (same intent). No AI call here.
- "Để mình viết sau": nothing written → OB10; otherwise the draft is kept
  first, then OB10 (no entry). If it cannot be kept: "Tiếp tục viết /
  Thử giữ bản nháp / Bỏ bản nháp". Back → OB06 keeps everything (the
  `FirstEntrySession` lives in the flow); changing the AI choice there
  keeps the text.
- Once saved, OB07 edits the same id: "Tiếp tục" when unchanged (no save),
  "Lưu thay đổi" when edited (same id, next `bodyVersion`). Back from OB08 /
  OB09 returns here; OB10 returns to OB09 when an entry exists.
- The ground hides when the content reaches its horizon (small screens,
  large text), so text never sits on the drawing.
- Nudaeng: `Deimage/Nudaeng writing-transparent.png`, the same desk crop as
  OB05–OB06; usually hidden here because the four sentences need the room.

## OB08 preparing

- Transient: entered only with an entry id, AI on and a reflection request
  running; keeps OB07's progress position. A quiet "analysing" moment: the
  saved label, then mid-screen an indeterminate spinner (no percentage),
  "Nhật ký đã lưu. Đang chuẩn bị phản hồi AI…" and "Bạn có thể đợi ở đây
  hoặc xem phản hồi sau.", the writing desk (120) on the ground below, and
  "Xem phản hồi sau" → OB09's pending variant.
- The stand-in service answers after 3 s to resemble a real service's
  latency in the demo; that is the service's delay, not a UI minimum.
- Leaves for OB09 the moment the request settles (ready, failed, timed out
  or cancelled): no minimum duration, and the request is never delayed for
  the mascot. A reflection already there for the same body version skips
  OB08; AI off never shows it. Resumed here with nothing running: straight
  on to OB09 (Thử lại there). Timeouts belong to the service, not the UI.
  Back → OB07.

## OB09 entry saved

- One layout for every variant (the CTA never moves): "Nhật ký đã lưu",
  title, the user's own mood ("Bạn chọn: …", never an AI mood), then:
  - AI ready: a Surface card "Gợi ý từ AI" (" · mô phỏng" for the stand-in),
    static text in open, tentative language;
  - AI off: no AI card and no nudge to turn AI on; title "Bạn đã ghi lại
    những dòng đầu tiên.";
  - AI pending / failed: "Phản hồi AI chưa sẵn sàng." with "Xem sau" (stop
    showing the wait; a late result still appears) or "Thử lại".
  The saved entry is always shown ("Nhật ký của bạn", long text folds).
  "Tiếp tục" → OB10, always enabled. No confetti or celebration emoji.
- `FirstReflection` (owned by the flow) asks `ReflectionService` only after
  a successful save and only when AI is on. A result belongs to one
  (entry id, body version) and is reused for that version. A newer request,
  a newer version or AI switched off makes a late response be ignored;
  switching AI off cancels the wait. Retry asks again for the same entry.
- `MockReflectionService` (`features/journal/data/reflection_service.dart`)
  is the deterministic stand-in (ADR-005): nothing leaves the device; it
  answers from which blanks were filled, never the screenshot's insight.
  The API version should call `POST /api/v1/ai/reflection` via the backend
  and support cancelling; pass it as `OnboardingFlow.reflections`.
- Nudaeng: the OB07 writing desk again (`deskScene`).

## OB10 reminders

- Title "Bạn muốn được nhắc vào lúc nào?", helper "Bạn có thể đặt lời nhắc
  hoặc để sau.", two cards both off at first: Buổi sáng 08:00, Buổi tối
  21:00 (local wall-clock). Each: sun / moon outline icon, title,
  description, the time (a button opening the 24 h time picker, labelled
  "Giờ nhắc buổi sáng, 08:00") and a labelled switch ("Nhắc Buổi sáng,
  08:00"). Layout: one row from 380 wide; narrower, time and switch move
  up beside the title and the description runs below; large text, time and
  switch get their own line.
- Toggles and the picker change the draft only: no permission prompt, no
  scheduling. CTA "Lưu lời nhắc" (and "Để sau") with a slot on; "Tiếp tục
  không nhắc" with both off (removes any reminder saved earlier).
- "Lưu lời nhắc" is the only place permission is asked: never asked → the
  system prompt then; already refused → no prompt again. Granted → each
  chosen slot is scheduled daily from its next occurrence (stable ids 1001
  morning, 1002 evening, so saving again replaces), the others cancelled,
  then OB11. Denied / unavailable → "Chưa bật được thông báo. Bạn có thể
  đổi trong Cài đặt." with "Tiếp tục" (→ OB11) and, when denied, "Mở cài
  đặt". Back from Settings with notifications allowed: the message clears
  and saving works again. One slot failing → "Chưa tạo được lời nhắc buổi
  tối." (and what was set), "Thử lại" or "Tiếp tục" (records only what was
  scheduled). Any edit clears the message.
- One notification text: "Một chút thời gian dành cho nhật ký của bạn".
- `ReminderService` (`features/reminders/data/reminder_service.dart`). The
  project has no notification plugin yet, so the app uses
  `SimulatedReminderService`: no system prompt is shown or faked and no
  notification will appear; after saving, a snack bar says it is simulated.
  Try each branch on a device with
  `--dart-define=REMINDER_SIM=denied|refuse|unavailable|fail-morning|fail-evening|fail-all`.
  A real implementation (e.g. flutter_local_notifications with time zone
  support, plus an app-settings opener) needs `pubspec.yaml` and platform
  setup (Android POST_NOTIFICATIONS / exact alarms, iOS authorization); pass
  it as `OnboardingFlow.reminders`.
- Background: the shared onboarding background (`AppColors.background`),
  like every other step; the yellow of "Nudaeng remind.png" clashed with
  Primary and flashed between OB09 and OB10. The artwork is
  split by `tool/build_remind_layers.py` into Nudaeng with the balloons
  (`ob10-nudaeng-balloons.png`, head 497, feet (459, 1078)) on the shared
  mascot line, and the star / balloon / heart strip
  (`ob10-remind-decor.png`) along the bottom behind the actions
  (`OnboardingStepScaffold.backdrop`), below the feet line so it never
  covers Nudaeng. The balloons rise above the head, so the whole image must
  fit (`OnboardingMascot.wholeCanvas`): it shows on 390×844 and 360×800;
  with less room, or while an error message is shown on 390×844, Nudaeng
  hides rather than shrinks or draws over the cards.

## OB11 ready

- Replaces the sample app's 7-day pledge and signature with an invitation:
  no promise, no checkbox, no "SIGNED", no Study challenge enrollment. The
  nickname, when there is one, is only a greeting ("Vy ơi,") above the
  title "Một khoảng nhỏ dành cho bạn."
- Paper card (Surface, border, soft shadow) with the invitation text.
- Summary from the real state, under the card:
  - entry saved → "Nhật ký đầu tiên đã được lưu.";
  - draft kept (also shown next to a saved entry edited after saving) →
    "Bạn có một bản nháp để tiếp tục khi sẵn sàng.";
  - neither → "Bạn có thể bắt đầu nhật ký đầu tiên ở Home.";
  - reminders scheduled → the actual slots and times ("Lời nhắc buổi sáng
    lúc 08:00 và buổi tối lúc 21:00 đã được bật."), plus "Bản thử nghiệm:
    chưa có thông báo thật." with the stand-in service;
  - none (skipped, refused, failed) → "Bạn có thể đặt lời nhắc sau."
- "Vào không gian của mình" → `complete()` → `OnboardingFlow.onComplete`;
  the app rebuilds and Home replaces the flow. If saving fails the screen
  stays with a message and "Thử lại"; answers, entry, draft and reminders
  are untouched, and the next launch resumes at OB11.
- Back → OB10.
- Nudaeng knitting (`ob11-nudaeng-yarn.png`, head 2, feet (118, 216)) cut
  from `tool/artwork_sources/Nudaeng OB11.jpg` by `tool/build_ob11_layer.py`:
  the flat yellow and the corner copyright line go, the app's background
  shows through. Standard mascot size and line; the yarn runs off to the
  right.
- Not done yet: Home does not open the onboarding draft
  (`FirstEntrySession.draftKey`) so the "bản nháp" line points to a draft
  that is kept but not yet reachable from Home.

## Journal store (shared with Home and J01)

- `JournalRepository` (interface) with `LocalJournalRepository` (this
  device, shared_preferences) used by the app today, and
  `InMemoryJournalRepository` for tests and screens without a scope.
- Home shows "Nhật ký gần nhất" in the Daily Reflection card once an entry
  exists; it opens J01 on that entry. J01 "Finish" now saves (new entry, or
  the same id when editing) before the reflection flow. A guided entry
  keeps its structured values while its text is unchanged; edited in J01
  it becomes free text.
- For the backend: an `ApiJournalRepository` should implement the same
  interface on `/api/v1/journals`. The contract (title / content / prompt /
  mood) needs, proposed: `guided` {template id, version, fields},
  `body_version`, timestamps, and drafts (or keep drafts on the device).
  When it is wired, update `DataPolicy.storage` (OB06).

## Mascot on OB02+ (`OnboardingMascot`)

One rule for every step, so Nudaeng never jumps between screens:

- Head to feet 96 high (`OnboardingMascot.figureHeight`; a seated scene may
  pass a taller `height` so the head stays the same size), feet centred on the
  screen and 12 above the actions. Each image gives its head top and feet
  in its own pixels (`MascotFrame`): OB02 run frames (306×319) head 2, feet
  (136, 275); OB03 guitar image (1254) head 92, feet (600, 1194).
- The feet line is the same with or without "Để sau": a step with one
  action leaves the room the secondary action would take
  (`OnboardingStepScaffold`).
- Less room than 108: hidden, never shrunk (OB03 on 390×844 and smaller
  shows no mascot; the list wins). Ground shadow and a slow breath on all
  steps; reduced motion: no breath.
- OB01's umbrella scene is the full-screen welcome illustration and is not
  bound by this rule; the wind transition carries it into OB02.
- Shared ground (`OnboardingGround`, drawn in code): a gently wavy horizon
  16 above the feet line, mint fill down to the screen's bottom (the actions
  float over it, as on OB01), a few flowers and grass tufts kept to the
  sides. Same line on every step, so steps read as one place; shown even
  when the mascot is hidden for lack of room; hidden while the keyboard is
  open.
- OB02 adds a speech bubble above Nudaeng (`MascotBubble`): "Chào {nickname}!"
  live as the user types, "Chào bạn!" when empty. It needs 56 more above the
  head; without that room only the bubble hides.

## Shared pieces

- `frame_sequence.dart`: plays PNG frames once, then optionally again after
  a random pause; between runs holds the last frame or swaps to a rest
  widget (kept mounted, told when it is resting); reduced motion shows the rest widget or frame 01.
- `onboarding_widgets.dart`: `OnboardingStepScaffold` (layout for OB02+),
  with an optional `background` colour and bottom `backdrop` (OB10),
  `OnboardingCta`, `OnboardingTextAction`, `OnboardingOptionCard` (OB03,
  OB04), `OnboardingTopBar` (Back +
  "Bước x/9"; not staggered, the fill slides from the previous step's), `GroundShadow`, `OnboardingStagger` + `StaggerItem`,
  `IdleBreath`.
- `falling_petals.dart`: `FallingPetals` (with optional gust) and
  `PetalGust`, sharing the petal sprite.
