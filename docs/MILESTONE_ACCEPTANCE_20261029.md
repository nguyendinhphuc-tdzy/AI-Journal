# Journal–AI–Album–Map: nghiệm thu trên máy Phúc (29/10/2026)

## Quyết định và phạm vi

- Tài khoản đăng nhập bật phản hồi AI mặc định; người dùng tắt/bật trong Profile. Khách không gửi nhật ký tới AI.
- Lần nghiệm thu này dùng Ollama trên chính máy Phúc với model local `qwen3:4b`. Dự định dùng Mac của Vy qua kết nối riêng được hoãn lại; app vẫn chỉ gọi FastAPI, không gọi Ollama trực tiếp.
- Hoàn thiện Journal, AI, Album và Map trước. Social backend đã có nhưng chưa nối social UI trong milestone này.
- Nhánh nghiệm thu xuất phát từ `integration/journal-cloud-runtime-20261027`, tích hợp thay đổi của PR #52–#63 và sửa các điểm giao nhau. Không merge các PR nguồn hay chạy migration trên Supabase chung.

## Luồng đã tích hợp

- AI: JWT bắt buộc, kiểm tra độ dài và giới hạn lượt gọi trong một process; hội thoại “Nhìn lại cùng bạn” gửi đủ các lượt hỏi đáp trong giới hạn nội dung. Phản hồi AI mặc định bật cho tài khoản, có công tắc Profile. Home không hiển thị lời nhận xét cảm xúc mẫu như thể AI đã đọc nhật ký.
- Journal: hiển thị cùng lúc bản ghi local và cloud, không bỏ qua cloud khi còn nhật ký local; streak tài khoản lấy từ server, không tự tạo số ngày khi API lỗi.
- Album: phân trang quá 100 album/kỷ niệm; không trả khóa ảnh private trong JSON; tải ảnh qua endpoint có xác thực; gom các lượt tải ảnh đồng thời vào cùng một request.
- Map: saved places local theo tài khoản, tìm kiếm qua lookup của phiên cloud, và không gắn nhãn “địa điểm mẫu” cho kết quả thật.
- Quyền riêng tư: khi bỏ chế độ khách, xóa thêm dữ liệu Study và PIN local; Android tắt backup dữ liệu app. Các thay đổi API được ghi trong `docs/API_CONTRACT.md`.

## Chạy nghiệm thu trên PC

1. Cài dependency vào `backend/.venv` bằng Python 3.11 và `backend/requirements.txt`; chạy `flutter pub get` trong `mobile`.
2. Cấu hình `backend/.env` riêng, không commit. Cần `DATABASE_URL`, `SUPABASE_URL` và `SUPABASE_PUBLISHABLE_KEY`. Backend dùng cùng Supabase Dev hiện tại.
3. Bật Ollama ở loopback và xác nhận model đã tải local (`ollama list`). Chạy `scripts/start_journal_cloud_backend.ps1 -OllamaModel qwen3:4b`. Launcher kiểm tra Alembic revision bằng truy vấn chỉ đọc và kiểm tra model trước khi chạy server; nó ghi đè `AI_PROVIDER=ollama` trong process, không sửa `.env`.
4. Chạy `backend/.venv/Scripts/python.exe -m scripts.ai_local_smoke --model qwen3:4b` từ thư mục `backend` để kiểm tra hai lời gọi AI thật bằng nhật ký giả lập.
5. Với Android emulator, backend URL là `http://10.0.2.2:8000/api/v1`. Đăng nhập bằng tài khoản thử nghiệm hợp lệ để gọi API cloud; Guest chỉ kiểm tra luồng local. Không dùng nhật ký thật khi thử AI.

## Giới hạn nghiệm thu

- Bộ test backend dùng SQLite; 3 test Postgres cần môi trường Postgres riêng. Preflight revision trên Supabase chung chỉ đọc, không thay thế bài thử ghi/đọc bằng tài khoản thử nghiệm.
- Rate limit AI hiện nằm trong RAM của một backend process; cần giải pháp dùng chung trước khi chạy nhiều worker hoặc public deployment.
- Album dùng offset pagination cho tương thích; insert/delete đồng thời giữa các trang có thể làm lệch trang. Cursor pagination là bước tiếp theo nếu cần snapshot chắc chắn.
- Social UI vẫn dùng luồng mẫu ở các chỗ chưa nối backend. Không coi các thông báo gửi bạn bè mẫu là gửi thật từ tài khoản cloud.

## Kết quả trên máy Phúc

- Backend: `78 passed, 3 skipped` trên SQLite; 3 bài Postgres được giữ cho môi trường Postgres riêng.
- Flutter: `684/684` widget và unit test đạt; `flutter analyze --no-pub` không có lỗi; `flutter build bundle --no-pub` thành công.
- Preflight: Supabase Dev khớp revision `20261028_15`; thao tác chỉ đọc và không chạy migration.
- Ollama: `qwen3:4b` local vượt qua kiểm tra model và smoke test thật cho cả `go_deeper` và `reflection` bằng nhật ký giả lập.
