# Đối chiếu flow và Nudaeng — 2026-10-13

Nguồn: note S02–S07 người dùng dán trong attachment `18646b72-5738-4b81-87e2-2276f563ad8f`,
các yêu cầu trước đó và ba câu trả lời xác nhận trong phiên này.
Phạm vi sửa: Study, tests của Study và asset/tool ND05. Không đổi API contract,
backend, core, navigation hoặc pubspec trong lượt đối chiếu này.

## Asset đã chốt

| Màn | Pose tĩnh / nguồn | Motion | Kết luận |
| --- | --- | --- | --- |
| S01 | `Study.jpg`, 189 × 136 trên panel PrimaryLight full-width ở đầu banner (150 × 108 khi màn hẹp hoặc chữ lớn) | Không | Đổi 13/10/2026: chỉ dùng Study.jpg tĩnh, bỏ GIF nghiêng đầu. Bố cục ảnh trên, nội dung và CTA 48 px full-width bên dưới theo app tham khảo người dùng gửi; banner khoảng 357 px ở 390 |
| S01 → S04 | Frame đầu (index 0) của `Chú chó nghiêng đầu đọc sách.gif`, 160 × 168 trên màn chờ toàn màn hình | `Chú chó nghiêng đầu đọc sách.gif`, phát 1 lần (1,6 giây) | Đổi 13/10/2026: bấm “Xem challenge” hiện màn chờ kiểu loading rồi mở S04; không Join; bỏ qua khi giảm chuyển động |
| S01 card | Không mascot, giữ icon thumbnail | Không | Đổi 13/10/2026: người dùng chốt bỏ Nudaeng ôm sách khỏi card để tối giản; banner là mascot duy nhất của S01 |
| S02 | Frame đầu (index 0) của `Chó Nudaeng lật trang sách.gif`, 108 × 132 đứng trên đường đất vẽ tay dưới thẻ tiêu đề | `Chó Nudaeng lật trang sách.gif`, ≤2 giây | Đổi 13/10/2026: lật sách mỗi lần mở; sau đó idle kiểu Rive bằng chính frame vẽ tay (nghỉ 3-6 giây rồi tự lật trang lại), thay cho kiểu co giãn bị giả; tắt khi giảm chuyển động |
| S03 | `Chó Bài học đọc hoặc video.jpg` | Không | Pose 64 px tại đầu panel thực hành; người dùng chốt dùng file laptop dù prose mô tả khác |
| S04 | `Mời.jpg` | `Nudaeng_gio_bang_ra_truoc_1_5s.gif`, ≤1,5 giây | Giữ đúng file, không replay khi scroll |
| S05 | `Pose chờ challenges.jpg` | GIF ND05 mới, 1,2 giây | Người dùng chốt giữ pose ngủ; yêu cầu tạo riêng check notebook + gật đầu |
| S06 | `Bạn đã hoàn thành challengs.jpg` | `Vẫy đuôi.gif`, ≤1,8 giây | Giữ đúng file chó nằm vẫy đuôi; tên JPG thực tế thiếu chữ “e” so với note |
| S07 | Frame ôm sách (index 4) | `Chú chó ôm sách đầy yêu thương.gif`, ≤1,8 giây | Dùng tên file thật; note viết nhầm “đây yêu thuơng” |

Runtime dùng các bản `*-transparent` của đúng nguồn trên. Chỉ ND05 là asset mới
do người dùng yêu cầu tạo; không thay nguồn khác bằng hình AI. Mapping nằm tại
`presentation/nudaeng_artwork.dart`.

## Flow đã kiểm tra và sửa trong lượt này

| Yêu cầu | Kết quả |
| --- | --- |
| Đọc bài cuối trước không đồng nghĩa xong cả khóa | Đã sửa; S07 chỉ mở khi tập lesson đã đọc đủ toàn bộ |
| Tiếp tục bài chưa hoàn tất | Đã sửa; chọn bài chưa đọc đầu tiên, kể cả khi học không theo thứ tự |
| Đọc lại không mất check hoặc tăng count | Đã sửa; reader nhận trạng thái đã đọc, nút không ghi lặp |
| S02 progress và CTA cập nhật sau reader | Đã sửa; có số bài/progress, đủ 100% đổi sang thực hành với prompt mẫu sẵn có |
| S07 “Về khóa học” | Đã sửa stack để trở lại S02 thay vì reader |
| ND05 chỉ chạy sau completion mới | Đã nối với sự kiện lưu của demo; không chạy khi mở progress cũ hoặc sau task cuối |
| Task cuối từ reflection sang S06 | Đã sửa; chờ return từ reflection rồi mở completion |
| Reopen S06 chỉ pose tĩnh | Đã sửa; “Xem kết quả” không replay celebration |
| S02 lần đầu/session, Back từ reader và scroll không replay | Đã có, tests kiểm tra |
| S03 không animation cạnh paragraph | Đã có; duy nhất pose tĩnh ở panel thực hành |
| Xem banner không tự Join; paused không tự resume | Đã có, tests kiểm tra |
| Framework không dựng lesson giả | Đã có; dùng các bước mẫu và CTA viết |

## Bổ sung sau khi người dùng xác nhận mock data và ba state nhiệm vụ

- `data/study_mock_data.dart`: ba bài khóa học, một case study, nội dung riêng,
  metadata, summary, prompt, framework steps và challenge prompts.
- Practice truyền đúng source ID; bài độc lập hiển thị 5 phút và giữ read state.
- Entry mẫu giữ ID, nội dung và context; association theo challenge/task chống
  lưu trùng trong session. Thực hành lesson không cộng completion challenge.
- Done mở entry; current mở editor hoặc draft; pending mở preview chỉ đọc.
- Paused/left vẫn mở được entry, primary resume mới cho viết tiếp. Menu Rời có
  xác nhận; resume bảo toàn progress, draft và entry.
- S06 hiển thị count thật, mở danh sách entry đúng challenge; Back về Study.
  Banner completed mở kết quả tĩnh. S04 có CTA kết quả khi completed.
- Reader dùng prompt từ fixture tương ứng và label “Về bài học”. S07 practice
  quay về S02. Course không có practice prompt dùng “Xem lại bài học”.
- Progress tween 200 ms khi giá trị đổi, không chạy từ 0 khi load tiến độ cũ.
- Pose ôm sách (S07) chọn frame index 4: frame đầu GIF vẫn đang đọc
  sách nên không phù hợp với “pose ôm sách tĩnh”. Giữ nguyên file nguồn.

## Giới hạn còn lại

| Phần | Trạng thái |
| --- | --- |
| Persistence / API | Từ 27/10/2026: bài viết lưu vào nhật ký chung trên máy (kèm nguồn), tiến độ và bản nháp lưu trên máy. Chưa đồng bộ server, chưa có Retry lỗi network hoặc partial commit. |
| AI | Reflection và Go Deeper vẫn là dữ liệu mẫu. |
| Video | Mock hiện có chỉ gồm article, chưa có video source/player/subtitle/error-retry; đã bỏ biểu tượng play gây hiểu nhầm khỏi card course. |
| Nhiều enrollment | Chỉ một challenge fixture; chưa có sheet chuyển giữa nhiều challenge hoặc xử lý catalog mất ID. |
| Course không có prompt | Đã có nhánh CTA xem lại lesson list; fixture khóa hiện tại có prompt nên chưa có ca widget riêng cho nhánh thiếu prompt. |

Không thay endpoint hoặc API contract trong lượt này. Những giới hạn trên được
nêu rõ thay vì coi các tests của demo là kiểm chứng backend.

## Phần thiếu note/dữ liệu đã hỏi người dùng

- ND05 chưa có filename: đã trả lời yêu cầu tạo GIF mới; hoàn thành.
- File khác tư thế prose: đã trả lời ưu tiên filename; áp dụng.
- Hai GIF S02: ban đầu chốt lật trang rồi ôm sách tĩnh; ngày 13/10/2026 đổi thành chỉ lật trang trong S02, card S01 không có mascot.
- S03 chưa có nguồn video và nội dung/prompt đã biên tập: người dùng yêu cầu tạo mock data; đã bổ sung.
- Sau “State nhiệm vụ:” không có bảng trong attachment: người dùng xác nhận done mở entry/current viết hoặc draft/pending preview; đã nối đầy đủ.

## Kiểm chứng

`flutter test test/features/study`: 21 tests pass, gồm regression học không theo
thứ tự, đọc lại, completion sau đủ bài, bảy task đi tới S06, danh sách entry, leave/resume giữ draft, reopen không animation,
GIF ND05 12 frame/1.200 ms/alpha mọi frame và các kiểm tra responsive trước đó.
Kiểm tra asset gốc tiếp tục xác nhận 131 frame GIF gốc được giữ nguyên timing.
Các tests này không chứng minh persistence, API hoặc video vì các phần đó chưa có.
