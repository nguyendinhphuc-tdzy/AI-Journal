import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A home-screen icon to pick in Hồ sơ: Nudaeng in a profession, or the
/// app's own. Generic names only, never a brand's.
///
/// [id] must match MainActivity.ICONS and the `Launcher_<id>` aliases in
/// AndroidManifest.xml; art and tints come from tool/app_icons/export.py.
enum AppIcon {
  standard('default', 'Mặc định', Color(0xFFEEF4F1)),
  security('security', 'Bảo vệ', Color(0xFFDCE6F0)),
  student('student', 'Học sinh', Color(0xFFF1E4CE)),
  guide('guide', 'Hướng dẫn viên', Color(0xFFD6E9E4)),
  restaurant('restaurant', 'Phục vụ nhà hàng', Color(0xFFF3DEDB)),
  office('office', 'Nhân viên văn phòng', Color(0xFFE4E5F1)),
  nurse('nurse', 'Y tá', Color(0xFFF4E1EA)),
  repair('repair', 'Thợ sửa chữa', Color(0xFFE6E2D3));

  const AppIcon(this.id, this.label, this.tint);

  final String id;
  final String label;

  /// The icon's background, as on the home screen.
  final Color tint;

  /// The picture shown in the picker (256 px).
  String get asset => 'assets/images/app-icon-$id.png';

  static AppIcon byId(String? id) =>
      values.firstWhere((icon) => icon.id == id, orElse: () => standard);
}

/// The icon on the home screen. Android keeps the choice itself (the
/// enabled launcher alias), so it outlives a restart and is the same for
/// every account on the phone; nothing is sent to the server.
abstract interface class AppIconSwitcher {
  /// Whether this phone can change it (Android only).
  bool get supported;

  Future<AppIcon> current();

  /// Changes it; some launchers take a few seconds or restart the app.
  Future<void> set(AppIcon icon);
}

class PlatformAppIconSwitcher implements AppIconSwitcher {
  const PlatformAppIconSwitcher();

  static const _channel = MethodChannel('ai_diary/app_icon');

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<AppIcon> current() async {
    if (!supported) return AppIcon.standard;
    try {
      return AppIcon.byId(await _channel.invokeMethod<String>('current'));
    } on MissingPluginException {
      return AppIcon.standard;
    }
  }

  @override
  Future<void> set(AppIcon icon) async {
    if (!supported) throw UnsupportedError('No launcher icons here');
    await _channel.invokeMethod<void>('set', {'id': icon.id});
  }
}
