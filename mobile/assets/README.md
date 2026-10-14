# Assets Directory

Thư mục chứa các tài nguyên tĩnh (hình ảnh, icon, mascot, ...) cho ứng dụng Mobile.

## Cấu trúc thư mục

- `images/`: Hình ảnh chung của ứng dụng (background, banner, onboarding illustration, ...).
- `icons/`: Các icon đồ họa tuỳ chỉnh (SVG/PNG).
- `mascot/`: Hình ảnh trạng thái của Mascot (idle, thinking, writing, happy, sleeping, walking, study, album, map).

## Cách sử dụng trong Flutter

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
