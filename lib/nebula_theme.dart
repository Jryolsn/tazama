/*
 * Tazama visual style: shared colors, shapes and the default background.
 * Licensed under GPL-3.0, see LICENSE.
 */

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

class Nebula {
  Nebula._();

  static const String fontFamily = 'Inter';

  static const Color deep = Color(0xFF0D0E12);
  static const Color violet = Color(0xFF1A1C22);
  static const Color surface = Color(0xFF16181D);
  static const Color surfaceHigh = Color(0xFF20232A);
  static const Color lavender = Color(0xFFE6E8EC);
  static const Color text = Color(0xFFF2F3F5);
  static const Color textMuted = Color(0xA6F2F3F5);

  /// Soft text shadow that keeps text readable on bright wallpapers.
  static const List<Shadow> textShadow = [Shadow(color: Color(0x80000000), blurRadius: 8, offset: Offset(0, 1))];

  static const double cardRadius = 6;

  static const LinearGradient baseGradient = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [violet, deep],
  );

  /// Paints the default background: a calm graphite gradient with a faint top light.
  /// Meant to be rendered once into a texture, not every frame.
  static void paintBackground(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..shader = baseGradient.createShader(rect));
    final light = const RadialGradient(
      center: Alignment(0.4, -1.2),
      radius: 1.2,
      colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = light);
  }

  static ui.Image renderBackground(Size size) {
    final recorder = ui.PictureRecorder();
    paintBackground(Canvas(recorder), Offset.zero & size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.width.round(), size.height.round());
    picture.dispose();
    return image;
  }
}
