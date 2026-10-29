# Danh sách kiểm tra việc của Phúc (29/10/2026)

Dùng khi Phúc báo xong từng việc. Mỗi mục gồm: cách thử và kết quả đúng. Đánh dấu `[x]` khi đạt.

**Chuẩn bị chung**
- Backend chạy ở `http://localhost:8000`, Ollama đang chạy.
- App chạy bằng `flutter run --dart-define-from-file=.env.journal-cloud.json`, đã đăng nhập một tài khoản thử.
- `TOKEN` là access token của tài khoản thử. Không dán token vào chat, issue hay PR.
- Với các lệnh `curl` bên dưới, `API=http://localhost:8000/api/v1`.

## Bảo mật

### 1. `/ai/*` phải đăng nhập và có giới hạn độ dài
- [ ] `curl -s -o /dev/null -w "%{http_code}" -X POST $API/ai/reflection -H 'Content-Type: application/json' -d '{"content":"thử"}'` → **401** (không có token).
- [ ] Gọi lại với `-H "Authorization: Bearer $TOKEN"` → **200**, có đủ `emotion`, `observation`, `reflection`, `question`.
- [ ] Gửi `content` dài 8.001 ký tự → **422**.
- [ ] Làm tương tự với `/ai/go-deeper`.
- [ ] Trong app: lưu nhật ký vẫn ra màn Phân tích. "Nhìn lại cùng bạn" vẫn ra câu hỏi.

### 2. Đổi mật khẩu database
- [ ] Phúc xác nhận đã đổi mật khẩu trên Supabase và cập nhật `DATABASE_URL` trong `.env` của mọi máy.
- [ ] `python -m alembic current` trong `backend/` vẫn chạy được.
- [ ] Trong app: lưu được một bài nhật ký.

### 3. `photo_path` không lộ key nội bộ của storage
- [ ] `GET $API/albums/{album_id}/memories` (có token) → các kỷ niệm có ảnh **không** trả đường dẫn storage kiểu `uuid/uuid/uuid/...jpg`. Chỉ trả cờ kiểu `photo_available: true`, hoặc trường đã thống nhất trong `API_CONTRACT.md`.
- [ ] Trong app: ảnh kỷ niệm vẫn hiện.

## Lỗi backend

### 4. `PATCH /me` với `discoverable: null`
- [ ] `curl -X PATCH $API/me -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"discoverable":null}'` → **không phải 500**: 422 hoặc 200 giữ nguyên giá trị, tùy cách Phúc chọn.

### 5. Lưu lại nhật ký không đổi nội dung thì không tăng `body_version`
- [ ] `GET $API/journals/{id}`, ghi lại `body_version`.
- [ ] `PUT` lại đúng nội dung đó, rồi `GET` lần nữa → `body_version` **không đổi**.
- [ ] Sửa một chữ rồi `PUT` → `body_version` tăng 1.

### 6. Phân trang album
- [ ] Album có hơn 100 kỷ niệm (tạo bằng script): app hiện đủ, không dừng ở 100.
- [ ] API trả `next_cursor` (hoặc cách phân trang đã thống nhất) giống `/journals`.

### 7. Chuỗi ngày là số thật
- [ ] Tài khoản mới, chưa viết bài nào: Trang chủ hiện **0 ngày**, không phải 2.
- [ ] Viết bài đầu tiên → màn chuỗi ngày báo **1 ngày**.
- [ ] Viết thêm một bài cùng ngày → số không đổi, không mở lại màn chuỗi ngày.
- [ ] Tắt app mở lại → số vẫn đúng, vì đọc từ `/streak`.

### 8. `docs/API_CONTRACT.md` khớp với backend
- [ ] Có đủ: `/journals`, `/albums` (cả ảnh), `/places`, `/ai/*`, `/me`, `/streak`, và các trường mới ở mục 19, 20.
- [ ] Mỗi endpoint ghi rõ yêu cầu đăng nhập, mã lỗi và giới hạn độ dài.

## App: dữ liệu và đăng nhập

### 9. `ApiClient`: giới hạn thời gian chờ và tự làm mới token
- [ ] Tắt backend rồi bấm lưu nhật ký → sau khoảng thời gian đã đặt, app báo lỗi, **không quay mãi**.
- [ ] Màn Phân tích chờ AI lâu (tắt Ollama) → hiện "Không thể kết nối AI lúc này." kèm nút "Thử lại AI".
- [ ] Để app mở hơn 1 giờ (token hết hạn) rồi lưu nhật ký → lưu được, **không bị đăng xuất**.

### 10. Album: một ảnh lỗi không làm hỏng cả album, sửa kỷ niệm không tải lại ảnh
- [ ] Làm hỏng một ảnh trên storage (hoặc chặn mạng khi tải ảnh) → album vẫn hiện các kỷ niệm khác. Kỷ niệm lỗi hiện không có ảnh, kèm dòng báo.
- [ ] Sửa ghi chú của kỷ niệm có ảnh → log backend **không có** request `PUT .../photo`.

### 11. Nhật ký cloud không tự tắt khi máy đã có nhật ký local
- [ ] Viết vài bài ở chế độ khách (local), thoát khách rồi đăng nhập tài khoản → app lưu lên cloud, hoặc báo rõ đang lưu ở đâu. Không âm thầm chuyển về lưu trên máy.

### 12. Đăng nhập Google, Facebook và số điện thoại
- [ ] Bấm "Tiếp tục với Google" rồi hủy ở trình duyệt → quay lại app, hiện câu báo lỗi tiếng Việt, không treo.
- [ ] Trong bản build thật (`AUTH_ENABLED=true`): **không** mở được màn Facebook mô phỏng.
- [ ] Số điện thoại (OTP): hoặc dùng được, hoặc nút bị ẩn hẳn. Không để nút mà bấm vào không có gì.

### 13. Khám phá khi `PLACES_CLOUD_ENABLED=false`
- [ ] Đăng nhập tài khoản A → **không** thấy 3 ghim mẫu và hòm thư mẫu.
- [ ] Lưu một ghim với tài khoản A, đăng xuất, đăng nhập B → B **không** thấy ghim của A.

### 14. Thoát chế độ khách thì xóa sạch dữ liệu khách
- [ ] Ở chế độ khách: học một bài Study, ghim một album. Bấm Đăng xuất → "Xóa và thoát".
- [ ] Vào lại chế độ khách → không còn tiến độ Study cũ, không còn ghim album.

### 15. `pubspec.lock`
- [ ] Đã commit bản có Supabase. Sau khi pull, `git status` trên máy Vy không còn `M mobile/pubspec.lock`.

## Cấu hình và nội dung

### 16. File `.env` mẫu
- [ ] `backend/.env.example` có thêm dòng `SUPABASE_PUBLISHABLE_KEY=`. Hiện file chỉ có `SUPABASE_URL`, trong khi backend cần key này để lưu ảnh album.
- [ ] Trong file `.env` gửi cho nhóm, `SUPABASE_PUBLISHABLE_KEY=` và `SUPABASE_URL=` nằm trên **2 dòng riêng**.
- [ ] Máy mới copy file mẫu, điền key → app không báo "Invalid API key".

### 17. Câu chữ chính sách ở OB05 (`data_policy.dart`)
Phần UI Vy đã làm trong PR #56: câu chữ mới, `local-ollama-demo-2`, Nudaeng không còn bị ẩn.
- [ ] Nhóm đã đọc và đồng ý câu chữ. Có người hiểu luật xem phần xin đồng ý trước khi có người dùng thật.

### 18. Prompt Ollama
- [ ] Phản hồi trả về có viết hoa đầu câu, không lỗi chính tả rõ ràng. Thử 5 bài khác nhau.
- [ ] Prompt đọc đúng dạng `Câu hỏi: … / Trả lời: …`: câu hỏi "Nhìn lại cùng bạn" ở vòng 2 nhắc tới ý của câu trả lời vòng 1.

## API mới (sau PR #56)

### 19. `/ai/reflection` trả thêm tiêu đề, chủ đề và câu trích dẫn
- [ ] Response có `title` (ngắn), `analysis`, `topics` (tối đa 3).
- [ ] `quote` là `{text, author, source}` hoặc `null`. Câu trả về **phải nằm trong danh sách 80 câu** (`mobile/lib/features/journal/data/quotes_vi.dart`), và chỉ là câu có `attribution: known` và `autoPick: true`.
- [ ] Trong app: màn Phân tích hiện tiêu đề mới. Bấm "Tiếp tục" ra câu trích dẫn backend chọn, tác giả hiện kiểu "– Tên".

### 20. Lưu đánh giá 👍/👎 ở màn Phân tích
- [ ] Bấm 👍 → backend lưu (gồm tài khoản, bài nhật ký, giá trị, thời gian). Bấm lại để bỏ chọn → lưu trạng thái bỏ chọn, hoặc xóa.
- [ ] Không gửi kèm nội dung nhật ký.
