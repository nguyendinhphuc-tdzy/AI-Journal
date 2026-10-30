---
title: Chính sách quyền riêng tư | AI-Journal
permalink: /privacy-policy.html
---

# Chính sách quyền riêng tư của AI-Journal

**Cập nhật: 30/10/2026 · Ngôn ngữ: Tiếng Việt**  
**Ứng dụng:** AI-Journal (ứng dụng nhật ký và phản hồi AI cho Android; hiện trong giai đoạn phát triển/thử nghiệm)

AI-Journal là ứng dụng viết nhật ký cá nhân. Chính sách này mô tả những loại dữ liệu có thể được xử lý khi dùng tài khoản, Facebook Login và các tính năng kết nối máy chủ; đồng thời giải thích cách liên hệ để yêu cầu xóa dữ liệu. Phạm vi xử lý thực tế tùy thuộc chức năng được bật và cách bạn sử dụng ứng dụng.

## 1. Đơn vị vận hành và liên hệ

AI-Journal hiện được vận hành dưới dạng dự án ứng dụng của nhóm phát triển AI-Journal. Nếu có câu hỏi về dữ liệu cá nhân, quyền riêng tư, Facebook Login hoặc yêu cầu xóa dữ liệu, liên hệ:

**Email liên hệ dự án:** [nguyendinhphuc2826@gmail.com](mailto:nguyendinhphuc2826@gmail.com?subject=AI-Journal%20-%20Quyen%20rieng%20tu)

Không gửi mật khẩu, mã OTP, JWT/access token, nội dung nhật ký hoặc thông tin nhạy cảm trong email ban đầu.

## 2. Những dữ liệu có thể được xử lý

- **Tài khoản và xác thực:** địa chỉ email, mã định danh người dùng và trạng thái xác thực qua Supabase Auth. Nếu bạn tự chọn **Đăng nhập bằng Facebook**, hệ thống xác thực có thể nhận thông tin hồ sơ cơ bản và email theo quyền bạn cho phép từ Meta/Facebook. AI-Journal không yêu cầu quyền truy cập danh bạ, danh sách bạn bè Facebook hoặc đăng bài lên Facebook để phục vụ chức năng đăng nhập hiện tại.
- **Nội dung do bạn tạo:** bài nhật ký, ngày giờ, câu trả lời theo gợi ý viết, nhãn/tâm trạng bạn chọn, album, kỷ niệm, ghi chú, địa điểm lưu và trích dẫn bạn chọn lưu. Nhật ký có thể chứa thông tin riêng tư do bạn chủ động nhập.
- **Bạn bè và tin nhắn trên ứng dụng:** username/tên hiển thị, lời mời kết bạn và trạng thái chặn, cuộc trò chuyện 1-1, tin văn bản, thời điểm gửi/đã đọc, địa điểm hoặc kỷ niệm mà bạn chủ động chọn chia sẻ. Tin nhắn và lịch sử trò chuyện được lưu trên server PostgreSQL để hai bên truy cập; đây **không phải** tính năng nhắn tin mã hóa đầu-cuối.
- **Phân tích AI:** khi chức năng AI được bật và bạn chủ động dùng phân tích, nội dung liên quan của bài viết có thể được gửi qua FastAPI của dự án tới Ollama được cấu hình trên máy của nhóm để tạo phản hồi, câu hỏi suy ngẫm và thông tin cảm xúc. Kết quả phân tích, nhóm/điểm cảm xúc và đánh giá thích/không thích có thể được lưu theo tài khoản cùng nhật ký. Điểm cảm xúc là quy ước hiển thị, không phải kết luận y tế.
- **Thống kê và nhận xét tuần:** dữ liệu tổng hợp từ nhật ký/phân tích đã lưu; phần nhận xét bằng AI chỉ được yêu cầu tạo khi bạn bấm chức năng tương ứng và có thể được lưu theo tuần trong tài khoản.
- **Dữ liệu trên thiết bị:** dữ liệu của chế độ khách, nhật ký cũ chưa đồng bộ và một số tùy chọn/giao diện có thể nằm trên thiết bị của bạn. Đăng nhập tài khoản không đồng nghĩa mọi dữ liệu cũ tự động tải lên máy chủ.
- **Tìm kiếm địa điểm (nếu bật):** từ khóa hoặc địa chỉ bạn nhập để tìm nơi chốn có thể được gửi qua backend tới Geoapify. Quyền vị trí của thiết bị chỉ được yêu cầu khi bạn dùng chức năng cần vị trí.
- **Dữ liệu kết nối kỹ thuật:** trong quá trình hoạt động, mạng, hệ điều hành, Supabase và các dịch vụ hạ tầng liên quan có thể xử lý dữ liệu kỹ thuật cần thiết để cung cấp kết nối, xác thực, vận hành và xử lý lỗi.

**Chia sẻ 24 giờ:** nội dung bài chia sẻ chỉ có hiệu lực trong 24 giờ; khi hết hạn hoặc thu hồi, phần xem trước của bài trong tin nhắn không còn hiển thị nội dung. Lịch sử hội thoại và thông tin tin nhắn đã được gửi có thể vẫn được lưu. Ghi chú riêng của album/địa điểm không được tự động gửi cho người nhận.

## 3. Mục đích sử dụng

Dữ liệu được xử lý để tạo và bảo vệ phiên đăng nhập, lưu/hiển thị nhật ký và nội dung bạn tạo, đồng bộ những tính năng cloud đã bật, quản lý kết bạn và truyền tin nhắn giữa những tài khoản đã kết bạn, phản hồi theo yêu cầu bằng AI, hiển thị thống kê, hỗ trợ lỗi và thực hiện yêu cầu liên quan đến tài khoản. Những tính năng chưa được bật không đồng nghĩa tự động thu thập dữ liệu cho tính năng đó.

## 4. Các hệ thống và bên nhận dữ liệu

- **Supabase:** dịch vụ Auth và PostgreSQL/Storage cho những dữ liệu được lưu trên tài khoản và các tính năng cloud tương ứng.
- **FastAPI và Ollama:** backend của dự án trung chuyển yêu cầu và thực hiện xử lý AI trên hệ thống Ollama mà nhóm cấu hình. Khi AI được tắt, ứng dụng không chủ động gửi nhật ký mới để phân tích AI qua các thao tác nêu trên.
- **Meta/Facebook:** nếu bạn chọn Facebook Login, Meta thực hiện bước xác thực và cung cấp những thông tin mà bạn chấp thuận cho nhà cung cấp đăng nhập.
- **Geoapify:** chỉ khi sử dụng tính năng tìm kiếm địa điểm có hỗ trợ nhà cung cấp này.

Chúng tôi không yêu cầu mật khẩu Facebook của bạn. Việc xử lý thông tin bởi các nhà cung cấp nêu trên còn chịu điều khoản và chính sách riêng của từng nhà cung cấp.

## 5. Nơi lưu và thời gian giữ dữ liệu

Nội dung mới trong chế độ nhật ký cloud có thể được lưu trên Supabase theo tài khoản; lịch sử tin nhắn và dấu đã đọc được lưu ở server để cả hai bên xem, kể cả sau khi hủy kết bạn (ở chế độ chỉ xem), cho đến khi có thao tác xóa dữ liệu/tài khoản hợp lệ; nội dung chế độ khách và bản sao chưa đồng bộ có thể vẫn nằm trên thiết bị. Phân tích AI mới lưu cùng nhật ký trên cloud có quan hệ xóa theo bài viết; nhận xét tuần và trích dẫn đã lưu là các bản ghi riêng. Dữ liệu có thể được giữ trong khi tài khoản/dịch vụ hoạt động hoặc đến khi bạn xóa nội dung hay yêu cầu xóa dữ liệu, trừ trường hợp cần giữ theo nghĩa vụ pháp lý hoặc phục vụ xử lý yêu cầu đang diễn ra. Dữ liệu sao lưu/hệ thống của nhà cung cấp có thể có chu kỳ lưu giữ riêng; nhóm sẽ thông báo giới hạn thực tế khi xử lý yêu cầu xóa.

Không nên xem việc xóa ứng dụng khỏi điện thoại, đăng xuất hoặc gỡ liên kết Facebook là yêu cầu xóa dữ liệu đã lưu trên máy chủ.

## 6. Lựa chọn và quyền của bạn

Bạn có thể tắt phản hồi AI trong phần Hồ sơ mà vẫn sử dụng chức năng viết nhật ký. Bạn có thể xóa từng nội dung trong những chức năng đã hỗ trợ và có thể yêu cầu nhóm xóa dữ liệu tài khoản.

Xem [Hướng dẫn xóa dữ liệu người dùng](data-deletion.html) để biết các bước thực hiện, bao gồm dữ liệu có nguồn gốc từ Facebook Login.

Bạn cũng có thể liên hệ email ở Mục 1 để yêu cầu biết thêm về cách sử dụng dữ liệu, yêu cầu sửa thông tin không chính xác hoặc trao đổi về yêu cầu xóa.

## 7. Bảo mật và lưu ý

Dữ liệu riêng tư được thiết kế truy cập qua phiên xác thực của người dùng và backend; tin nhắn chỉ được mở bởi hai thành viên của hội thoại, không công khai nhật ký qua giao diện API ẩn danh. Tuy nhiên, không có hệ thống nào bảo đảm an toàn tuyệt đối. Bạn nên giữ bí mật thông tin đăng nhập và hạn chế nhập dữ liệu không muốn ứng dụng xử lý.

## 8. Thay đổi chính sách

Khi cách lưu trữ, tính năng AI, nhà cung cấp hoặc kênh hỗ trợ thay đổi, chúng tôi sẽ cập nhật trang này và ngày cập nhật. Bản thử nghiệm đang tiếp tục hoàn thiện và cần được nhóm rà soát trước khi phát hành rộng rãi.

---

### English summary

**AI-Journal Privacy Policy — Last updated October 30, 2026.** AI-Journal is a journaling application under development. Depending on enabled features, it processes account identifiers and email via Supabase Auth; legacy Facebook profile/email data if you previously used Facebook Login; friendships, private one-to-one messages and read receipts stored on the server; journal entries and saved content; and optional AI analysis and weekly summaries via the project's FastAPI/Ollama service. Cloud account data is stored using Supabase, while certain guest or legacy items may remain on the device. Geoapify may process search terms when place search is used. You may request deletion of account-associated data, including Facebook Login-associated data, using [the data deletion instructions](data-deletion.html) or by emailing [nguyendinhphuc2826@gmail.com](mailto:nguyendinhphuc2826@gmail.com). Do not send passwords, tokens or journal text in the initial request.

[Trang chủ](index.html) · [Hướng dẫn xóa dữ liệu](data-deletion.html)
