# Assets Directory

Thư mục chứa các tài nguyên tĩnh (hình ảnh, icon, mascot, ...) cho ứng dụng Mobile.

## Cấu trúc thư mục

- `images/`: Hình ảnh chung của ứng dụng (background, banner, onboarding illustration, ...).
- `icons/`: Các icon đồ họa tuỳ chỉnh (SVG/PNG).
- `mascot/`: Hình ảnh trạng thái của Mascot (idle, thinking, writing, happy, sleeping, walking, study, album, map).

## Cách sử dụng trong Flutter

Hiện tại ba thư mục chỉ chứa `.gitkeep`, chưa có ảnh thật. Các đường dẫn
trong ví dụ bên dưới là minh họa; chỉ sử dụng sau khi thêm file tương ứng,
nếu không Flutter sẽ báo `Unable to load asset`. UI đang dùng
`MascotPlaceholder` để hiển thị trạng thái bằng chữ, chưa tự động đọc ảnh
từ thư mục `mascot/`.

Sau khi copy hình ảnh vào thư mục tương ứng, bạn có thể gọi trong widget:

```dart
Image.asset('assets/images/your_image.png')
```

Hoặc sử dụng với `AssetImage`:

```dart
CircleAvatar(
  backgroundImage: AssetImage('assets/mascot/idle.png'),
)
```

Ba thư mục đã được khai báo trong `mobile/pubspec.yaml`. Đường dẫn và tên
file phải khớp cả chữ hoa/chữ thường. Nếu thêm thư mục con, khai báo thư mục
con đó trong `pubspec.yaml` (ngoại trừ các biến thể độ phân giải như `2.0x/`).
Sau khi thêm asset hoặc thay đổi khai báo, chạy `flutter pub get` và khởi
động lại ứng dụng.

`Image.asset` và `AssetImage` dùng cho ảnh raster như PNG/JPEG/WebP. SVG cần
renderer riêng; dự án hiện chưa có dependency hỗ trợ SVG.

Kiểm tra từ thư mục `mobile/` bằng `flutter analyze`, `flutter test` và
`flutter build bundle`.
