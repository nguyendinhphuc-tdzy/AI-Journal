---
title: Hướng dẫn xóa dữ liệu người dùng | AI-Journal
permalink: /data-deletion.html
---

# Hướng dẫn yêu cầu xóa dữ liệu người dùng — AI-Journal

**Cập nhật: 30/10/2026 · Tiếng Việt / English summary below**

Trang này dành cho người dùng AI-Journal, bao gồm người dùng từng đăng nhập bằng Facebook/Meta. Bạn có thể yêu cầu xóa dữ liệu gắn với tài khoản AI-Journal. Hiện ứng dụng **chưa có chức năng tự xóa toàn bộ tài khoản** được xác minh hoàn chỉnh; vì vậy, yêu cầu xóa tài khoản được tiếp nhận và xử lý thủ công bởi nhóm phát triển.

## 1. Gửi yêu cầu xóa dữ liệu

Gửi email tới:

**[nguyendinhphuc2826@gmail.com](mailto:nguyendinhphuc2826@gmail.com?subject=AI-Journal%20-%20Yeu%20cau%20xoa%20du%20lieu)**

**Tiêu đề gợi ý:** `AI-Journal - Yêu cầu xóa dữ liệu`

Nội dung có thể viết ngắn gọn:

> Tôi muốn yêu cầu xóa dữ liệu gắn với tài khoản AI-Journal của mình. Email tài khoản của tôi là [địa chỉ email đăng ký]. Tôi muốn [xóa toàn bộ tài khoản và dữ liệu / chỉ xóa dữ liệu liên quan đến Facebook Login]. Xin hướng dẫn bước xác minh quyền sở hữu tài khoản.

Chỉ cung cấp email đăng ký và phạm vi yêu cầu ở bước đầu. **Không gửi** mật khẩu, mã OTP, access token, nội dung nhật ký, ảnh riêng tư hay ảnh giấy tờ qua email ban đầu.

Nếu không còn truy cập email đăng ký, hãy nêu rõ điều đó và yêu cầu một cách xác minh phù hợp. Chúng tôi có thể cần xác minh bạn là chủ tài khoản trước khi xóa dữ liệu nhằm tránh yêu cầu giả mạo.

## 2. Dữ liệu nào sẽ được xem xét xóa?

Tùy phạm vi yêu cầu và những tính năng bạn đã dùng, yêu cầu xóa toàn bộ tài khoản sẽ bao gồm những dữ liệu gắn với tài khoản trên hệ thống AI-Journal: hồ sơ/tài khoản xác thực Supabase, bài nhật ký, kết quả phân tích AI và đánh giá, trích dẫn đã lưu, nhận xét tuần, album/kỷ niệm, ghi chú, địa điểm, lời mời kết bạn, các cuộc trò chuyện, tin nhắn và trạng thái đã đọc cùng các liên kết liên quan nếu có. Khi xóa tài khoản Supabase Auth, các bảng trò chuyện/tin nhắn dùng khóa ngoại cascade; nhóm vẫn phải kiểm tra kết quả xóa thực tế và lưu ý khả năng sao lưu còn tồn tại theo chu kỳ của nhà cung cấp.

Nếu bạn **chỉ yêu cầu xóa dữ liệu từ Facebook Login**, hãy ghi rõ điều đó. Nhóm sẽ xử lý dữ liệu xác thực/liên kết tài khoản Facebook được lưu hoặc nhận bởi AI-Journal theo phạm vi có thể xác minh, đồng thời giải thích nếu thao tác đó ảnh hưởng đến việc tiếp tục đăng nhập vào tài khoản hiện có.

Dữ liệu trên thiết bị của bạn (chẳng hạn dữ liệu chế độ khách hoặc bản sao chưa đồng bộ) không nhất thiết bị xóa từ xa cùng dữ liệu máy chủ. Bạn có thể xóa dữ liệu ứng dụng trong cài đặt Android hoặc gỡ cài đặt sau khi bảo đảm không cần giữ các bản sao đó. Xóa dữ liệu trên điện thoại **không tự động xóa** bản ghi còn trên máy chủ.

## 3. Quy trình xử lý và thời gian

1. Nhóm nhận email và xác nhận phạm vi yêu cầu.
2. Nếu cần, nhóm thực hiện bước xác minh quyền sở hữu tài khoản qua kênh phù hợp.
3. Sau khi xác minh, nhóm thực hiện thao tác xóa trên những hệ thống do AI-Journal quản lý, kiểm tra các bản ghi liên quan và thông báo kết quả bằng email. Mục tiêu xử lý yêu cầu hợp lệ là **trong 30 ngày kể từ khi hoàn tất xác minh**; nếu có trở ngại về pháp lý hoặc kỹ thuật, nhóm sẽ giải thích việc kéo dài thời gian.
4. Một số dữ liệu sao lưu, log kỹ thuật hoặc thông tin phải giữ theo quy định có thể cần thời gian xử lý khác; nhóm sẽ giải thích ngoại lệ khi xác nhận kết quả, không tuyên bố xóa nếu chưa kiểm tra.

**Lưu ý:** Quy trình này là hướng dẫn gửi yêu cầu; gửi email không làm dữ liệu tự động bị xóa ngay. Không có bước nào yêu cầu bạn công khai thông tin nhạy cảm trên GitHub hoặc mạng xã hội.

## 4. Nếu bạn đăng nhập bằng Facebook

Bạn có thể thu hồi quyền kết nối AI-Journal từ Facebook bằng cách mở **Facebook → Settings & privacy → Settings → Apps and websites**, tìm AI-Journal và chọn gỡ bỏ ứng dụng (tên và vị trí mục có thể thay đổi theo giao diện Facebook).

**Gỡ ứng dụng khỏi Facebook chỉ thu hồi quyền liên kết**, không thay thế yêu cầu xóa dữ liệu đã được AI-Journal lưu. Để xóa dữ liệu liên quan, hãy gửi yêu cầu qua email ở Mục 1. Bạn không cần cung cấp mật khẩu Facebook.

## 5. Hỏi thêm về quyền riêng tư

Xem [Chính sách quyền riêng tư AI-Journal](privacy-policy.html) hoặc liên hệ [nguyendinhphuc2826@gmail.com](mailto:nguyendinhphuc2826@gmail.com?subject=AI-Journal%20-%20Quyen%20rieng%20tu).

---

### English — User Data Deletion Instructions

If you used **AI-Journal**, including **Facebook Login**, you can request deletion of data associated with your AI-Journal account. Email **[nguyendinhphuc2826@gmail.com](mailto:nguyendinhphuc2826@gmail.com?subject=AI-Journal%20-%20Data%20Deletion%20Request)** with the subject **"AI-Journal - Data Deletion Request"**, your registered email address, and whether you want (a) all account-associated data deleted or (b) data associated with Facebook Login removed. Do **not** email passwords, access tokens, journal entries or identity documents in the initial message. We may verify account ownership to protect against unauthorized requests. Our target is to process verified requests within 30 days, subject to explained legal or technical limitations. Removing AI-Journal in Facebook's *Apps and websites* revokes access but does **not** itself delete information already stored by AI-Journal. The app does not yet provide a verified automatic full-account deletion function; requests are handled manually.

[Home](index.html) · [Privacy Policy](privacy-policy.html)
