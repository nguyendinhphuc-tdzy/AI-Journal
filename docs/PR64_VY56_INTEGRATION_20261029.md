# PR #64 — tích hợp UI mới nhất từ PR #56 (29/10/2026)

## Nguồn và nguyên tắc

- Lấy PR #56 tại `b2e553f99` làm chuẩn cho Flutter UI, biểu đồ cảm xúc tuần, lưu/xem lại phân tích, trích dẫn, OB05/OB06 và test tương ứng.
- Giữ FastAPI, JWT, giới hạn AI, quota theo process, Supabase Storage proxy, Album/Memory pagination, Journal local+cloud, streak server, timeout và token refresh từ PR #64.
- Giữ nguyên UI chưa có backend: `AnalysisArchive` vẫn lưu trên thiết bị theo tài khoản, `emotion_scale` quy đổi 10 nhóm cảm xúc ở client; KHÔNG dựng giả endpoint `/insights/week`, không tự tạo điểm/nhận xét tuần.
- `remote_album_repository.dart` và test Album dùng bản PR #64 vì đã tích hợp đổi `photo_path` thành `photo_available`, pagination và tải ảnh đồng thời.
- `ai_conversation.dart` dùng bản PR #64 để chặn độ dài prompt theo giới hạn backend (8000 ký tự), vẫn hỗ trợ các lượt hỏi đáp trong UI Vy.
- Không đổi database, không migration, không merge vào nhánh integration; PR #64 vẫn là PR nghiệm thu để review.

## Hạng mục cố ý giữ lại

- #8: rà soát đầy đủ API_CONTRACT.md.
- #10: ảnh tải lỗi riêng lẻ / tránh upload lại ảnh không thay đổi.
- #12: OAuth/OTP/Facebook mock.
- #17: phê duyệt nội dung chính sách, xử lý lựa chọn AI cũ và đồng bộ chính sách lưu phân tích.
- Việc mới của Insights: server lưu phân tích theo journal và body_version; `mood_group` / `mood_score`; API `GET /insights/week` và tổng kết tuần bằng AI.

## Kiểm thử

Sau commit hợp nhất, cần chờ GitHub CI chạy trên đúng HEAD mới: Backend CI, Flutter analyze/test/bundle. Kết quả CI của hai PR riêng lẻ KHÔNG thay thế kiểm thử sau tích hợp. Sau CI tiếp tục E2E bằng tài khoản thử nghiệm trên Android với local FastAPI/Ollama, đặc biệt thư viện album, Home -> Cảm xúc tuần này, nhật ký local+cloud và phiên AI.
