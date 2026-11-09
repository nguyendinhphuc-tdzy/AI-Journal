# Giai đoạn 2 — Album Cloud: rollout và nghiệm thu 2 thiết bị

## Đã có sẵn trong integration
- FastAPI owner-scoped Album/Memory CRUD và photo GET/PUT/DELETE qua end-user Supabase JWT.
- Bucket `journal-memory-private` đã tồn tại trên AI-Journal-Dev, private, `file_size_limit=5242880` và MIME JPEG/PNG/WebP; RLS policies SELECT/INSERT/DELETE theo user UUID.
- `album_memories.photo_path` đã có từ migration `20261028_10`; database hiện revision `20261030_17`. **Không có migration Phase 2**.
- Local Album/Memory vẫn hiển thị riêng, không đồng bộ hoặc chia sẻ tự động.
- Một ảnh/kỷ niệm, ghi chú bắt buộc cho Memory cloud; cloud photo-only không hỗ trợ.

## Kích hoạt chỉ trong môi trường Dev
- Flutter test: sao chép `mobile/journal_cloud.album_dev.example.json` thành **file untracked** `mobile/.env.journal-cloud.json`, hoặc chỉ đặt `ALBUM_CLOUD_ENABLED=true` vào file hiện có và giữ nguyên Supabase Publishable Key thật.
- `AUTH_ENABLED=true`, phải có Supabase session hợp lệ. Android emulator FastAPI URL `http://10.0.2.2:8000/api/v1`.
- Backend giữ `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `DATABASE_URL` hợp lệ; **không** đưa DB password, service_role, JWT secret hay Meta App Secret vào Flutter.
- File `mobile/journal_cloud.example.json` mặc định vẫn **tắt** Album Cloud. Guest/demo không được tạo cloud upload.

## Explicit import album local (không tự upload)
- Trong tab Kỷ niệm, khi user đã login và bật cloud, nút **Nhập album từ máy lên Cloud** xuất hiện nếu có album local.
- Chọn đúng album, app kiểm tra trước toàn bộ kỷ niệm: ghi chú không rỗng, ảnh còn tồn tại, kích thước 1–5 MiB và JPEG/PNG/WebP. Album đã khóa không import để tránh bỏ qua PIN.
- Hiển thị hội thoại **Đồng ý nhập**: chuyển ảnh riêng tư lên cloud, vẫn giữ toàn bộ bản local gốc.
- Checkpoint chỉ lưu *local album ID*, *cloud album ID* và *local memory IDs hoàn tất* theo từng tài khoản. Không lưu ảnh/token trong preferences.
- Sau khi thao tác thành công, import lại trả về cloud album đã tạo, không tự tạo thêm.
- Nếu upload/response bị gián đoạn ở memory đang xử lý, UI **không tự động gửi lại** vì kết quả server có thể đã được commit. Người dùng phải kiểm tra album cloud; cần xây dựng tác vụ hòa giải/recovery mới để giải quyết bản ghi in-flight.
- Photo-only, PIN-locked, ảnh mất/không hợp lệ: không import và không cố biến đổi dữ liệu cá nhân để qua xác thực.

## Bảng nghiệm thu thủ công bằng hai thiết bị
Dùng A/B là hai máy ảo Android khác nhau hoặc 1 máy thật + 1 emulator, **cùng Supabase account** lúc kiểm tra đồng bộ và hai account khác nhau lúc kiểm tra cách ly.

1. Device A đăng nhập user X, bật `ALBUM_CLOUD_ENABLED=true`; tạo Album mới, lưu Memory có ghi chú + ảnh PNG/JPEG dưới 5 MiB. Xác nhận upload thành công.
2. Device B đăng nhập **cùng user X**, bật cloud, mở danh sách album, thấy album/Memory, tải ảnh thật, mở đúng ảnh.
3. Device B sửa ghi chú/đổi ảnh, mở lại Device A, refresh Album thấy nội dung và ảnh mới. Thử đường truyền kém/ngoại tuyến để biết lỗi tải; dữ liệu server không bị tự xóa khi fail.
4. Thiết bị A có Album local từ trước, bấm import → xác nhận. Cả A và B thấy **bản cloud**, A vẫn có bản local; ảnh gốc còn trên máy.
5. Lặp lại import Album đã xong, phải không tạo bản copy cloud mới.
6. Đăng xuất X, đăng nhập user Y trên B: không thấy Album/Memory/ảnh cloud của X. Dùng Y thử gọi URL API của X → 404/403 (không rò thông tin).
7. Thử ảnh > 5 MiB, file giả JPEG, ảnh bị xóa trước upload, JWT hết hạn, Storage 503: hiện lỗi, không gây mất local.
8. Xóa Memory/Album, kiểm tra metadata và private Storage object được dọn; nếu network fail giữa các bước, đánh dấu reconciliation cần xử lý.

## Giới hạn chưa nghiệm thu qua CI
- **Không thể thực hiện 2-device E2E chỉ bằng GitHub CI**: cần máy Vy/người thật đăng nhập và backend local chạy.
- Storage object + PostgreSQL transaction không atomic; cần job reconciliation để xử lý orphan sau lỗi mạng hiếm gặp.
- Không tự đổi default flag trên các bản phát hành; rollout Dev trước, kiểm tra dữ liệu riêng tư và quota/size rồi mới cân nhắc bật rộng rãi.
