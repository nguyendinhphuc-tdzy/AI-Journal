import 'package:flutter/material.dart';

/// The four tabs, the same in the app shell and on screens pushed above it
/// (J01, the streak), so the bottom bar never changes look between them.
const appDestinations = [
  NavigationDestination(
      icon: Icon(Icons.menu_book_outlined), label: 'Trang chủ'),
  NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Học tập'),
  NavigationDestination(
      icon: Icon(Icons.photo_album_outlined), label: 'Kỷ niệm'),
  NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Khám phá'),
];
