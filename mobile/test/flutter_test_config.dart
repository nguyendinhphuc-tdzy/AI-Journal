import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

// Only substitute the native map view. Live tiles/gestures require device tests.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  MapLibrePlatform.createInstance = () => _TestMapsPlatform();
  await testMain();
}

class _TestMapsPlatform extends MapLibrePlatform {
  @override
  Widget buildView(
          Map<String, dynamic> creationParams,
          OnPlatformViewCreatedCallback onPlatformViewCreated,
          Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers) =>
      const SizedBox.expand();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
