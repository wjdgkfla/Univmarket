// Regenerates every app icon from BrandMarkPainter.
// Run: flutter test tool/export_icons_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:univmarket_app/widgets/brand_mark.dart';

const ink = Color(0xFF17191C);

Future<void> render(
  String path,
  int px, {
  bool rounded = false,
  bool transparentTile = false,
  double markScale = 1,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size.square(px.toDouble());
  if (rounded) {
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(px * 0.225)),
    );
  }
  BrandMarkPainter(
    color: Colors.white,
    knockout: transparentTile ? Colors.transparent : ink,
    tile: transparentTile ? Colors.transparent : ink,
    markScale: markScale,
  ).paint(canvas, size);
  final image = await recorder.endRecording().toImage(px, px);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export icons', () async {
    const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    for (final (name, px) in [
      ('20x20@1x', 20),
      ('20x20@2x', 40),
      ('20x20@3x', 60),
      ('29x29@1x', 29),
      ('29x29@2x', 58),
      ('29x29@3x', 87),
      ('40x40@1x', 40),
      ('40x40@2x', 80),
      ('40x40@3x', 120),
      ('60x60@2x', 120),
      ('60x60@3x', 180),
      ('76x76@1x', 76),
      ('76x76@2x', 152),
      ('83.5x83.5@2x', 167),
      ('1024x1024@1x', 1024),
    ]) {
      await render('$ios/Icon-App-$name.png', px);
    }

    const res = 'android/app/src/main/res';
    for (final (dpi, legacy, fg) in [
      ('mdpi', 48, 108),
      ('hdpi', 72, 162),
      ('xhdpi', 96, 216),
      ('xxhdpi', 144, 324),
      ('xxxhdpi', 192, 432),
    ]) {
      await render('$res/mipmap-$dpi/ic_launcher.png', legacy, rounded: true);
      // Adaptive foreground: the mark alone, inside the 66dp safe zone.
      await render(
        '$res/mipmap-$dpi/ic_launcher_foreground.png',
        fg,
        transparentTile: true,
        markScale: 0.78,
      );
    }

    await render('web/icons/Icon-192.png', 192, rounded: true);
    await render('web/icons/Icon-512.png', 512, rounded: true);
    await render('web/icons/Icon-maskable-192.png', 192, markScale: 0.8);
    await render('web/icons/Icon-maskable-512.png', 512, markScale: 0.8);
    await render('web/favicon.png', 32, rounded: true);
  });
}
