# Study / Challenges UI

The refresh uses bundled Nunito headings and Be Vietnam Pro body text. Font
licenses are in `assets/fonts/`; fonts and the supplied Nudaeng illustrations work
offline. Feature typography lives in `presentation/study_theme.dart`.

The banner shares one layout for suggested, active and paused enrollment. It
wraps for narrow screens and large text. Its Nudaeng is the static Study.jpg
cutout (189 × 136, or 150 × 108 when narrow or at large text) standing on the
bottom edge of a full-width PrimaryLight art panel, with the copy and a
full-width 48 px CTA below. This top-art layout follows a reference app the
product owner supplied on 13/10/2026 and replaces the spec's 96 × 112 side
mascot; the banner is about 357 px tall at 390 px with normal text, above the
176-208 px reference, while the filter row and first card stay in view.
Elsewhere, Nudaeng shows the GIF's first frame as a
poster (never the idle pose first), plays it once, then returns to the
explicitly paired idle artwork, with a 240 ms dissolve when that pose is a
separate drawing (S04, S05), and stops for reduced motion, hidden tabs/routes, or
an inactive app.

Banner behavior beyond the S01 spec, confirmed by the product owner on
13/10/2026 and kept intentionally:
- a left challenge shows the eyebrow “Đã rời challenge” and opens S05;
- at 7/7 tasks the CTA reads “Xem kết quả” and opens S06 without replaying
  the celebration;
- while a course is in progress, the suggested-challenge CTA is outlined so
  “Tiếp tục học” stays the primary action. The app uses transparent cutouts of the supplied artwork; the
original source files are preserved alongside the cutouts.

Minimal shared-file changes:
- `pubspec.yaml`: register the two fonts and the existing illustration directories.
- `navigation/app_shell.dart`: enable tickers only in the selected tab, so the
  Study entrance animation does not play before the user opens Study.

## Motion (spec section 14)

Shared in `presentation/study_motion.dart`; enter = easeOutCubic, state
change = easeInOut.
| Trigger | Implementation |
| --- | --- |
| First S01 visit | `StudyEntrance`: fade + rise 8 px, 280 ms, once, input never blocked. Starts when the Study tab's tickers turn on, which relies on the `app_shell.dart` TickerMode change. |
| Press card/button | `StudyPressable`: scale 0.98 in 80 ms, back in 120 ms, via raw pointers so the action fires at once. Disabled buttons do not scale. |
| Filter/sort | Results cross-fade 180 ms (easeInOut); banner is static and never replays. |
| Child detail | `StudyRoute`: fade + 12 px slide, 280 ms; Back reverses. |
| Sheets | `sheetAnimationStyle` 300 ms open / 220 ms close, no bounce. |
| Progress | 200 ms easeInOut tween, only when the value changes. |
| Task check | Icon fades/scales in over 180 ms when the task's done state changes after save. |
| Mascot | Pauses behind other routes, in the background, out of the viewport (fidgets skip their turn), and is static with reduced motion. |

Reduced motion removes scale/slide/rise: the entrance is skipped, routes and
sheets use a 120 ms fade. No sound is played. `StudyRoute` replaces the
platform page transition, so the iOS edge-swipe back gesture is not available
on these routes (Android back and the app bar Back still work).

## Loading, empty and error (spec section 15)

Done in the mock: filter with no result keeps the banner and offers “Xóa bộ
lọc”; saving shows “Đang lưu…” in a fixed-size button and only J03 says
“Entry đã lưu”; disabled editor actions show a one-line reason in reserved
space so nothing jumps; paused/left S05 explains why writing is disabled.
Not implemented because the catalog, join, save, AI and progress calls are
synchronous fixtures that never fail: S01 skeleton, empty catalog (static
hugging Nudaeng), catalog fetch error, lesson/video error, join error, save
error with Retry, AI-not-ready and progress-sync Retry. No artificial delay
was added to fake them; they belong with the real API integration.

## Demo limitations

The existing local fixture remains in use. Enrollment, task progress, entries, and drafts
are kept in memory for this app session, with no backend or disk persistence.
Only one challenge exists in the fixture, so choosing between multiple active /
paused enrollments is not implemented. Banner task counts and progress are
calculated from that fixture and the completed task set.

Mock entries retain content and stable task associations in the session.
Completed tasks open those entries, future tasks offer read-only previews, and
S06 opens the linked entry list. Retrying a task save does not create a second
entry in the demo. Pause/leave/resume keep drafts and entries. Persistence and
network failures remain outside the mock contract. AI reflection remains a
fixture. Only “Mới nhất” is exposed because sort metrics are unavailable.

## Validation

`flutter analyze`

`flutter test test/features/study/study_screen_test.dart`

Widget coverage checks 360/390/430 logical pixel layouts at 1× and 2× text scale,
suggestion navigation without enrollment, paused/resume behavior, draft recovery,
and progress after saving. Build and inspect the Android app with
`flutter run -d emulator-5554` when the emulator is available.

## Artwork mapping from the PDF

All artwork is selected explicitly in `presentation/nudaeng_artwork.dart`.
No generic mascot fallback is used.

| Screen | Idle artwork | One-shot animation |
| --- | --- | --- |
| S01 Study banner | `Deimage/Study.jpg` | None (static by product decision, 13/10/2026) |
| S01 → S04 hand-off (“Xem challenge”) | First frame (index 0) of `NudaenggifDe/Chú chó nghiêng đầu đọc sách.gif` | Same GIF, one pass (1.6 s), then S04 replaces the screen |
| S02 Course / Framework hero | First frame (index 0) of `NudaenggifDe/Chó Nudaeng lật trang sách.gif`, with a living idle loop | Same GIF, one pass (≤ 2 s), on every open |
| S03 Reader practice panel | `Deimage/Chó Bài học đọc hoặc video.jpg` | None |
| S04 Challenge detail | `Deimage/Mời.jpg` | `NudaenggifDe/Nudaeng_gio_bang_ra_truoc_1_5s.gif` |
| S05 Challenge progress | `Deimage/Pose chờ challenges.jpg` | Newly generated `NudaenggifDe/ND05-check-notebook-transparent.gif`, 1.2 s, on a new non-final task completion only |
| S06 Challenge completion, first time | First frame (index 0) of `NudaenggifDe/Vẫy đuôi.gif`, with a living idle loop | Same GIF, one pass (≤ 1.8 s); never dissolves into the completion image |
| S06 Challenge completion, reopened (“Xem kết quả”) | `Deimage/Bạn đã hoàn thành challengs.jpg` | None |
| S07 Course completion | Hugging frame (index 4) of `NudaenggifDe/Chú chó ôm sách đầy yêu thương.gif` | Same GIF |

S01 content cards carry no mascot (icon thumbnails only), so the banner is the
single Nudaeng on the overview. The banner no longer plays
`Chú chó nghiêng đầu đọc sách.gif`: it is a different drawing from Study.jpg
(glasses, near-square crop), and swapping between them read as clutter. That
GIF now plays only in the S01 → S04 hand-off (see below). Study.jpg is landscape,
so its slot follows the 498:359 cutout ratio.

The PDF spells the S06 image “Bạn đã hoàn thành challenges.jpg”; the supplied
file is spelled “Bạn đã hoàn thành challengs.jpg”. The supplied S07 GIF uses
“đầy yêu thương” rather than the PDF's typo “đây yêu thuơng”. Paths preserve the
actual filenames, without renaming or replacing the source files.
J02/J03 do not name supplied files, so they no longer borrow the Study banner's
reading mascot. Their existing mock content and controls remain available.

## Transparent cutouts

The app uses `*-transparent.png` siblings of the five JPGs in `assets/Deimage/`
and `*-transparent.gif` siblings of the five GIFs in `assets/NudaenggifDe/`.
The table above identifies the original sources. Source filenames and artwork
remain unchanged. No AI-generated redraw is used by the app.

`mobile/tool/strip_nudaeng_backgrounds.py` creates the cutouts deterministically
with Pillow, NumPy and SciPy. It removes edge-connected neutral backdrops and
detached background decoration, preserves interior whites and attached props,
and trims empty margins. All frames of a GIF share a single crop to avoid jitter.
GIF transparency uses a reserved palette entry and disposal mode 2. All 131
animation frames, their individual durations and loop settings are preserved.

Rebuild from the repository root:

```sh
python3 -m venv /tmp/nudaeng-cutout-env
/tmp/nudaeng-cutout-env/bin/python -m pip install pillow numpy scipy
/tmp/nudaeng-cutout-env/bin/python mobile/tool/strip_nudaeng_backgrounds.py
```

`flutter test test/features/study` checks transparency in every output frame,
matching GIF frame counts/durations, correct idle artwork, and existing UI flows.

## S01 → S04 hand-off

The suggested-challenge CTA “Xem challenge” fades (200 ms) into a full-screen
Surface hand-off: Nudaeng 160 × 168 holds the book, tilts its head once, and
settles on the GIF's first frame above “Đang mở challenge…”. When the motion
finishes (`NudaengView.onFinished`), S04 replaces the hand-off, so Back returns
to S01. Nothing is joined. With reduced motion the hand-off is skipped and S04
opens directly. Active/paused CTAs still open S05 without a hand-off.
The motion runs in its own screen rather than in the banner, so the banner
never swaps between Study.jpg and the differently drawn GIF.

## J03 after a challenge task

When a non-final task is saved, J03 shows a PrimaryLight “Hẹn bạn ngày mai”
notice with the next task's number and prompt, noting that a missed day keeps
progress. Actions are docked so they stay visible: primary “Về challenge”
returns to S05; secondary “Viết tiếp nhiệm vụ N” returns to S05 and opens that
task's editor right away, because tasks are positions, not calendar locks.
The final task still goes to S06 with no notice. No reminder or notification
is scheduled for “ngày mai”; that needs a backend/notification decision.

## Detail layout (S02 / S03)

Following a reference app supplied on 13/10/2026, course, framework and
reading details share one editorial layout (`study_detail_layout.dart`):
- `StudyTitleCard`: a dark slab with a hand-inked wobbly edge, the centred
  title and a few sparkles kept in the side gutters (teal for courses, ink for
  frameworks, warm brown for readings).
- `StudyGroundScene` (S02 only): a full-bleed inked ground line with Nudaeng
  108 × 132 standing on it and a soft shadow.
- Uppercase eyebrow, a 28 px title (24 in the reader), muted description and
  a duration line; sections use uppercase headings with check or numbered
  lines. The CTA floats as a pill over a fade instead of a bordered bar.
The reader keeps its card static and its single 64 px mascot in the practice
panel, so the article itself stays free of motion.

## S02 / S03 mascot placement

Course and framework detail (S02) display the 96 px page-turn mascot in the
hero. Its first frame shows as a poster during the incoming route transition;
the GIF then plays once (at most two seconds) and settles on that same first
frame, with no swap to another drawing. It plays on every open of a detail
(changed 13/10/2026). Returning from the reader is the same visit, so it does
not replay.

After the page-turn the mascot does not freeze. A Rive-style idle
(`NudaengArtwork.idleFidget`) rests on the GIF's first frame, then replays the
hand-drawn page-turn after a varied 3-6 s pause, so Nudaeng seems to move on
its own with real frames rather than a transformed still. Fidgets wait while
another route covers S02 or the app is in the background, and never run with
reduced motion. No `.riv` asset or `rive` package is needed.

The reader (S03), including standalone articles, shows one static 64 px lesson
mascot at the start of the “Thử viết từ bài học này” panel near the end of the
article. It is intentionally absent from the article header and paragraphs.
Widget tests open these actual routes and verify decoded, visible artwork.

## Note reconciliation (2026-10-13)

The user confirmed that parenthesized filenames take priority over prose pose
descriptions: the supplied sleeping/laptop/lying-tail-wagging poses stay in use.
S02 plays page-turn on every open, then idles alive on its own first frame (changed 13/10/2026).
ND05 is the only newly generated asset, explicitly requested by the user because
no matching source file was supplied. Generation provenance and full prompt are
in `../../../tool/artwork_sources/README.md`.

Course completion now requires every lesson to be marked read (in any order).
Resume selects the first unread lesson; reopening a read lesson keeps its check.
Course progress and the completed practice CTA update immediately. S07 returns
to the course. In the local demo, returning from reflection after the last
challenge task opens S06; reopening results stays static. ND05 only plays on
new, non-final completion events and never when loading old progress.

See [FLOW_ASSET_AUDIT.md](FLOW_ASSET_AUDIT.md) for remaining gaps. These UI fixes
do not implement production enrollment, entry persistence, or task associations.

## User-requested mock content

`data/study_mock_data.dart` contains three distinct course articles, a case study,
summaries, practice prompts, framework steps and seven challenge prompts. Reader
metadata comes from its lesson; practice carries the correct source ID. The
fixtures are articles only: no video source/player is claimed.

Validation includes 21 tests covering out-of-order course progress, all seven
tasks through completion and linked entry viewing, preview/current/done actions,
pause/leave/resume draft retention, idempotent mock association, and ND05
transparency/timing.
