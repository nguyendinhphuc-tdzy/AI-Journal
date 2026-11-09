# Giai đoạn 1 — Username và kết bạn bằng tài khoản thật

## Mục tiêu
- Người dùng nhập **"Mình nên gọi bạn là gì?"** (OB02) sẽ được lưu tên hiển thị vào `user_profiles.display_name` của đúng Supabase Auth user, nếu đã đăng nhập và backend truy cập được. Nếu offline, dữ liệu tại máy không mất; có cơ chế đồng bộ khi đăng nhập lại mà không ghi đè tên đã chỉnh trực tiếp trên cloud.
- **Username** (ví dụ `@vytuong`) là định danh duy nhất do người dùng đặt ở màn **Explore → Bạn bè AI-Journal**. Cho phép 3–24 ký tự a–z, 0–9, dấu gạch dưới; server chuẩn hóa chữ thường, index DB đảm bảo duy nhất. Tên hiển thị có thể trùng nhau và giữ dấu tiếng Việt.
- `discoverable` mặc định **false**; người dùng phải tự bật **Cho phép tìm thấy tôi**. Không bật công khai chỉ vì vừa nhập biệt danh hoặc đăng nhập Facebook.
- Search theo username prefix hoặc một đoạn tên hiển thị (tối thiểu 3 ký tự, tối đa 20 kết quả), chỉ trả `user_id`, `display_name`, `username`. Không hiển thị email, SĐT hay dữ liệu nhật ký.
- Gửi lời mời, chấp nhận, hủy lời mời, hủy kết bạn dùng `/friends` thật. Mock Friends/Space vẫn giữ cho bản demo/guest; tài khoản Supabase không hiển thị bạn bè mẫu.

## Backend / Database
- Alembic **20261030_17** thêm `user_profiles.username VARCHAR(24) NULL` và unique constraint `uq_user_profiles_username`. Migration **additive**, không đổi hay xóa tài khoản cũ.
- `PATCH /me` nhận `username` tùy chọn, trả 409 nếu username trùng sau khi chuẩn hóa.
- `GET /friends/discover?q=...` hỗ trợ `@username` hoặc tên hiển thị của hồ sơ cho phép tìm; người bị chặn không xuất hiện.
- `GET /friends` thêm trường `display_name`, `username` của bên còn lại để Flutter hiển thị đúng tên, không dùng email.

## Release / testing gate
1. Review PR, CI Flutter/backend và diễn tập migration trên disposable PostgreSQL CI. **Không chạy migration trên Supabase dùng chung trước khi chấp thuận**; local backend preflight sẽ chủ động từ chối chạy nếu revision DB không khớp.
2. Backup database và kiểm tra schema revision Dev = `20261029_16`, sau đó mới được phép migration `20261030_17` theo quy trình phát hành đã thống nhất.
3. Hai tài khoản A/B: tạo username khác nhau, bật opt-in, tìm @handle, A gửi lời mời, B chấp nhận, kiểm tra A/B thấy bạn trong danh sách; A hủy. Thử username trùng, tìm chính mình, chặn tài khoản, truy cập JWT của user khác, đăng xuất đổi tài khoản.
4. Đảm bảo tên OB02 được đồng bộ khi có backend, nhưng `discoverable` vẫn false; màn tìm kiếm không tự làm lộ tên/nhật ký.
5. Không công bố chia sẻ nhật ký/album/địa điểm qua kết bạn trong PR này. Chia sẻ 24h cần một giai đoạn riêng với lựa chọn đối tượng và quyền truy cập rõ ràng.

## Không thuộc phạm vi
- Email/Google/Facebook OAuth E2E: theo yêu cầu chủ dự án, không kiểm thử email trong giai đoạn này.
- Đồng bộ album, tile map, AI quota.
- Tự động liên kết tài khoản Facebook và tài khoản email theo địa chỉ trùng nhau.
