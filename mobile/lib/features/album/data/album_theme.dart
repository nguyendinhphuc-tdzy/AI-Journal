import 'package:flutter/painting.dart';

import '../../../core/theme/app_colors.dart';

/// An album cover theme: a static Nudaeng pose on the cover and the colour of
/// its washi tape. Themes never change the app palette, the CTA, navigation,
/// body font or system states.
///
/// Poses are the supplied Nudaeng artwork, cut out by
/// `tool/build_album_layers.py`; none is drawn for the app.
class AlbumTheme {
  const AlbumTheme._(this.id, this.label, this.pose, this.tape);

  final String id;
  final String label;

  /// Static pose on the cover; null for the plain folder.
  final String? pose;
  final Color tape;

  static const classic =
      AlbumTheme._('classic', 'Cổ điển', null, AppColors.warmAccent);

  static const all = [
    classic,
    AlbumTheme._('curious', 'Hoài nghi',
        'assets/Deimage/album-theme-curious.png', AppColors.softAccent),
    AlbumTheme._(
        'sad', 'Buồn', 'assets/Deimage/album-theme-sad.png', AppColors.primary),
    AlbumTheme._('shy', 'Ngại ngùng', 'assets/Deimage/album-theme-shy.png',
        AppColors.warmAccent),
    AlbumTheme._('scarf', 'Quàng khăn', 'assets/Deimage/album-theme-scarf.png',
        AppColors.primaryDark),
    AlbumTheme._('reading', 'Đọc sách',
        'assets/Deimage/album-theme-reading.png', AppColors.positive),
  ];

  /// Unknown or retired ids fall back to [classic].
  static AlbumTheme of(String id) =>
      all.firstWhere((theme) => theme.id == id, orElse: () => classic);
}
